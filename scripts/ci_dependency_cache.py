#!/usr/bin/env python3
"""Optional GitHub cache of public HA packages, never the runner's whole store."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import zipfile

from scripts import candidate_ci

CHECKS = {"ha-behavior-tests", "ha-robot-cleaning-tests"}
ARCHIVE = "dependencies.export"

# Evaluate the public package recipe, not our flake or NUC configuration. Only
# the public nixpkgs-hass pin and this public overlay are in scope. In particular
# no tnote, agents-workspace, Rex, host data or test results can become roots.
PUBLIC_ROOTS = """
let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  locked = lock.nodes.${lock.nodes.root.inputs.nixpkgs-hass}.locked;
  source = builtins.fetchTree {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    inherit (locked) rev narHash;
  };
  pkgs = import source.outPath {
    system = "x86_64-linux";
    overlays = [
      (import ./overlays/home-assistant-mcp-schema-compat {
        inputs.nixpkgs-hass = source.outPath;
      })
    ];
  };
  # Use the public NixOS module's package default, just as the HA checks do.
  # No repository host configuration is imported, and no check flags change.
  hass = (import (source.outPath + "/nixos/lib/eval-config.nix") {
    system = "x86_64-linux";
    inherit pkgs;
    modules = [];
  }).config.services.home-assistant.package;
in map (p: p.outPath) ((map (name: hass.${name}) hass.outputs) ++ hass.propagatedBuildInputs)
"""


def trusted_push():
    if (
        os.environ.get("GITHUB_EVENT_NAME") != "push"
        or os.environ.get("GITHUB_REPOSITORY") != candidate_ci.REPOSITORY
    ):
        return False
    sha = os.environ.get("GITHUB_SHA", "")
    ref = os.environ.get("GITHUB_REF", "")
    if not re.fullmatch(candidate_ci.SHA, sha):
        return False
    if ref != "refs/heads/main":
        match = re.fullmatch(
            f"refs/heads/candidate/({candidate_ci.SHA})/({candidate_ci.SHA})", ref
        )
        if not match or match[2] != sha:
            return False
    return candidate_ci.git("rev-parse", "HEAD") == sha


def public_paths():
    roots = json.loads(
        subprocess.check_output(
            ["nix", "eval", "--json", "--impure", "--expr", PUBLIC_ROOTS],
            text=True,
            stderr=subprocess.PIPE,
            timeout=120,
        )
    )
    realized = [path for path in roots if Path(path).exists()]
    if not realized:
        return []
    paths = subprocess.check_output(
        ["nix-store", "--query", "--requisites", *realized],
        text=True,
        stderr=subprocess.PIPE,
        timeout=120,
    ).splitlines()
    for path in paths:
        if not re.fullmatch(r"/nix/store/[0-9abcdfghijklmnpqrsvwxyz]{32}-.+", path):
            raise ValueError("Not a store path")
        name = Path(path).name[33:]
        if name.endswith(".drv") or name.startswith(
            (
                "ha-behavior-tests",
                "ha-robot-cleaning-tests",
                "vm-test-run-",
                "nixos-test-driver-",
            )
        ):
            raise ValueError("Not a public package output")
    return paths


def export(directory):
    paths = public_paths()
    if not paths:
        return
    directory.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=directory) as temporary:
        archive = Path(temporary) / ARCHIVE
        with archive.open("wb") as output:
            subprocess.run(
                ["nix-store", "--export", *paths],
                stdout=output,
                stderr=subprocess.PIPE,
                check=True,
                timeout=180,
            )
        archive.replace(directory / ARCHIVE)
    print(f"Public HA cache: exported {len(paths)} public store paths", file=sys.stderr)
    print("ready=true")


def restore_candidate(directory):
    # Branch caches cannot flow candidate -> main. Carry this public-only
    # archive separately; never widen the existing empty-output artifact.
    if os.environ.get("GITHUB_REF") != "refs/heads/main":
        return
    sha, base = os.environ["GITHUB_SHA"], os.environ["VALIDATION_BASE"]
    url = candidate_ci.passing_candidate(base, sha)
    run_id = int(url.rsplit("/", 1)[1])
    run = candidate_ci.github(f"actions/runs/{run_id}")
    if any(
        run[key]["full_name"] != candidate_ci.REPOSITORY
        for key in ("repository", "head_repository")
    ):
        raise ValueError("Candidate run is from another repository")
    name = f"public-ha-v1-{sha}-{run['run_attempt']}"
    artifacts = candidate_ci.github(f"actions/runs/{run_id}/artifacts?per_page=100")[
        "artifacts"
    ]
    matches = [a for a in artifacts if a["name"] == name and not a["expired"]]
    if len(matches) != 1:
        return
    directory.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=directory) as temporary:
        archive = Path(temporary) / "artifact.zip"
        with archive.open("wb") as output:
            subprocess.run(
                [
                    "gh",
                    "api",
                    "--hostname",
                    "github.com",
                    f"repos/{candidate_ci.REPOSITORY}/actions/artifacts/{matches[0]['id']}/zip",
                ],
                stdout=output,
                stderr=subprocess.PIPE,
                check=True,
                timeout=180,
            )
        with zipfile.ZipFile(archive) as zipped:
            if zipped.namelist() != [ARCHIVE]:
                raise ValueError("Unexpected public dependency archive")
            zipped.extract(ARCHIVE, temporary)
        if (
            candidate_ci.github(f"actions/runs/{run_id}") != run
            or candidate_ci.passing_candidate(base, sha) != url
        ):
            raise ValueError("Candidate CI changed while fetching dependencies")
        (Path(temporary) / ARCHIVE).replace(directory / ARCHIVE)
    print(f"Public HA cache: fetched public dependencies from {url}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("plan")
    commands.add_parser("restore").add_argument("directory", type=Path)
    commands.add_parser("restore-candidate").add_argument("directory", type=Path)
    commands.add_parser("export").add_argument("directory", type=Path)
    args = parser.parse_args()
    try:
        if not trusted_push():
            return 0
        if args.command == "plan":
            selection = json.loads(
                subprocess.check_output(
                    [sys.executable, "scripts/validation.py", "--ci", "--plan"],
                    text=True,
                    stderr=subprocess.PIPE,
                    timeout=30,
                )
            )
            if CHECKS.intersection(selection["checks"]):
                print("enabled=true")
        elif args.command == "export":
            export(args.directory)
        else:
            if args.command == "restore-candidate":
                restore_candidate(args.directory)
            if (archive := args.directory / ARCHIVE).is_file():
                with archive.open("rb") as source:
                    subprocess.run(
                        ["nix-store", "--import"],
                        stdin=source,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        check=True,
                        timeout=180,
                    )
                print("Public HA cache: imported public dependencies")
    except (
        ValueError,
        KeyError,
        TypeError,
        OSError,
        subprocess.SubprocessError,
        zipfile.BadZipFile,
    ) as error:
        print(
            f"Public HA cache unavailable ({type(error).__name__}); normal validation required",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
