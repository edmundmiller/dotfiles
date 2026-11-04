#!/usr/bin/env -S uv run --script
# /// script
# dependencies = []
# ///
"""Refresh only Pi's version, source hash, and npm dependency lock/hash."""

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile
from urllib.request import urlopen


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path, help="Writable overlays/pi directory")
    parser.add_argument("version", help="Exact Pi release version")
    args = parser.parse_args()
    if not re.fullmatch(r"\d+\.\d+\.\d+", args.version):
        parser.error("version must be an exact stable release, for example 1.5.0")

    hashes_path = args.directory / "hashes.json"
    current = json.loads(hashes_path.read_text())
    if args.version == current["version"]:
        print(f"Pi {args.version} is already pinned; continuing to rebuild.")
        return
    if tuple(map(int, args.version.split("."))) < tuple(map(int, current["version"].split("."))):
        parser.error(f"refusing to downgrade Pi from {current['version']} to {args.version}")

    url = f"https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-{args.version}.tgz"
    with tempfile.TemporaryDirectory(prefix="pi-update-") as tmp:
        work = Path(tmp)
        with urlopen(url, timeout=60) as response:
            tarball = response.read()
        archive = work / "package.tgz"
        archive.write_bytes(tarball)
        with tarfile.open(archive) as package:
            package.extractall(work, filter="data")
        package_dir = work / "package"
        manifest = json.loads((package_dir / "package.json").read_text())
        if manifest["version"] != args.version:
            parser.error("downloaded package version does not match the requested release")

        # Generate the same registry lock format used by llm-agents.nix.
        (package_dir / "npm-shrinkwrap.json").unlink(missing_ok=True)
        subprocess.run(
            ["npm", "install", "--package-lock-only", "--ignore-scripts", "--no-audit", "--no-fund"],
            cwd=package_dir,
            check=True,
        )
        lock = package_dir / "package-lock.json"
        result = subprocess.run(
            ["prefetch-npm-deps", str(lock)],
            env=os.environ | {"NPM_FETCHER_VERSION": "2"},
            text=True,
            stdout=subprocess.PIPE,
            check=True,
        )
        hashes = {
            "version": args.version,
            "sourceHash": "sha256-" + base64.b64encode(hashlib.sha256(tarball).digest()).decode(),
            "npmDepsHash": result.stdout.strip(),
        }
        # Do not change either source file until the download, lock, and hash succeed.
        (args.directory / "package-lock.json").write_text(lock.read_text())
        hashes_path.write_text(json.dumps(hashes, indent=2) + "\n")
    print(f"Pinned Pi {args.version}. Rebuild through hey re to activate it.")


if __name__ == "__main__":
    main()
