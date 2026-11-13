#!/usr/bin/env python3
"""Transfer only empty Nix check outputs from successful exact candidates.

GitHub branch caches cannot flow from candidate to main. Run artifacts can,
but are public here: never archive the store, sources, closures or credentials.
This optional optimization does not certify CI or replace the validation runner.
"""

import argparse
import base64
import io
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import zipfile

from scripts import candidate_ci
from scripts.validation import CHECKS, LINUX_CHECKS

VERSION = "empty-checks-v1"
LIMIT = 1024 * 1024


def number(value):
    return struct.pack("<Q", value)


def string(value):
    data = value.encode()
    return number(len(data)) + data + b"\0" * (-len(data) % 8)


def empty_export(path, kind, deriver):
    """Canonical nix-store export with no contents, references or signatures.

    Comparing the entire stream, not just its filesystem payload, prevents
    metadata or future Nix export extensions from publishing private bytes.
    Never use this to synthesize a result: save compares it to Nix's real export.
    """
    tokens = ["nix-archive-1", "(", "type", kind]
    if kind == "regular":
        tokens += ["contents", ""]
    tokens += [")"]
    return (
        number(1)
        + b"".join(string(token) for token in tokens)
        + number(0x4558494E)
        + string(path)
        + number(0)
        + string(deriver)
        + number(0)
        + number(0)
    )


def checked_export(entry):
    name, path, kind, deriver = (entry[k] for k in ("check", "path", "kind", "deriver"))
    if name not in CHECKS | LINUX_CHECKS or kind not in ("regular", "directory"):
        raise ValueError("Not a portable empty check output")
    pattern = rf"/nix/store/[0-9abcdfghijklmnpqrsvwxyz]{{32}}-{re.escape(name)}"
    if not re.fullmatch(pattern, path) or (
        deriver and not re.fullmatch(pattern + r"\.drv", deriver)
    ):
        raise ValueError("Output or deriver does not have the public check name")
    data = base64.b64decode(entry["export"], validate=True)
    if data != empty_export(path, kind, deriver):
        raise ValueError("Export contains more than an empty check output")
    return data


def save(directory, outputs):
    entries = []
    for output in outputs:
        name, path = output.split("=", 1)
        file = Path(path)
        # Reject symlinks, executable files, nonempty outputs and closures before
        # invoking export. The byte-for-byte check below is the publication gate.
        if file.is_symlink():
            continue
        if (
            file.is_file()
            and file.stat().st_size == 0
            and not file.stat().st_mode & 0o111
        ):
            kind = "regular"
        elif file.is_dir() and not any(file.iterdir()):
            kind = "directory"
        else:
            continue
        deriver = subprocess.check_output(
            ["nix-store", "--query", "--deriver", path], text=True, timeout=30
        ).strip()
        if deriver == "unknown-deriver":
            deriver = ""
        data = subprocess.check_output(["nix-store", "--export", path], timeout=30)
        entry = dict(
            check=name,
            path=path,
            kind=kind,
            deriver=deriver,
            export=base64.b64encode(data).decode(),
        )
        try:
            checked_export(entry)
        except ValueError:
            continue
        entries.append(entry)
    payload = json.dumps(dict(version=VERSION, entries=entries)).encode()
    if len(payload) > LIMIT:
        raise ValueError("Check cache exceeds size limit")
    target = Path(directory)
    target.mkdir(parents=True, exist_ok=True)
    (target / "checks.json").write_bytes(payload)
    print(f"Check cache: exported {len(entries)} empty outputs ({len(payload)} bytes)")


def restore():
    if (
        os.environ.get("GITHUB_EVENT_NAME") != "push"
        or os.environ.get("GITHUB_REF") != "refs/heads/main"
    ):
        raise ValueError("Restore is only for main pushes")
    sha, base = os.environ["GITHUB_SHA"], os.environ["VALIDATION_BASE"]
    if candidate_ci.git("rev-parse", "HEAD") != sha:
        raise ValueError("Checkout does not match main push")
    # Reuse admission's latest-run/latest-attempt and required-context checks.
    # A PR artifact with the same name or SHA is never a trusted source.
    url = candidate_ci.passing_candidate(base, sha)
    run_id = int(url.rsplit("/", 1)[1])
    run = candidate_ci.github(f"actions/runs/{run_id}")
    if any(
        run[key]["full_name"] != candidate_ci.REPOSITORY
        for key in ("repository", "head_repository")
    ):
        raise ValueError("Candidate run is from another repository")
    name = f"{VERSION}-{sha}-{run['run_attempt']}"
    artifacts = candidate_ci.github(f"actions/runs/{run_id}/artifacts?per_page=100")[
        "artifacts"
    ]
    matches = [a for a in artifacts if a["name"] == name and not a["expired"]]
    if len(matches) != 1 or matches[0]["size_in_bytes"] > LIMIT:
        raise ValueError("No unique, unexpired candidate check cache")
    archive = subprocess.check_output(
        [
            "gh",
            "api",
            "--hostname",
            "github.com",
            f"repos/{candidate_ci.REPOSITORY}/actions/artifacts/{matches[0]['id']}/zip",
        ],
        timeout=60,
    )
    with zipfile.ZipFile(io.BytesIO(archive)) as zipped:
        if (
            zipped.namelist() != ["checks.json"]
            or zipped.getinfo("checks.json").file_size > LIMIT
        ):
            raise ValueError("Unexpected check cache archive")
        payload = json.loads(zipped.read("checks.json"))
    if payload["version"] != VERSION:
        raise ValueError("Unknown check cache format")
    # Validate the entire artifact before importing any of it.
    exports = [checked_export(entry) for entry in payload["entries"]]
    if (
        candidate_ci.github(f"actions/runs/{run_id}") != run
        or candidate_ci.passing_candidate(base, sha) != url
    ):
        raise ValueError("Candidate CI changed while fetching cache")
    for data in exports:
        subprocess.run(["nix-store", "--import"], input=data, check=True, timeout=30)
    print(f"Check cache: imported {len(exports)} empty outputs from {url}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("restore")
    command = commands.add_parser("save")
    command.add_argument("directory")
    command.add_argument("outputs", nargs="*")
    args = parser.parse_args()
    try:
        if args.command == "restore":
            restore()
        else:
            save(args.directory, args.outputs)
    except (
        ValueError,
        KeyError,
        TypeError,
        OSError,
        subprocess.SubprocessError,
        zipfile.BadZipFile,
    ) as error:
        # Cache misses never skip or hide validation failures. Avoid logging
        # arbitrary subprocess output, which could contain private information.
        print(
            f"Check cache unavailable ({type(error).__name__}); normal validation still required."
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
