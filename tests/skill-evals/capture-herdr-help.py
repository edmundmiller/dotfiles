#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Capture the installed herdr's help tree into herdr-help-corpus.json.

The skill evals replay help from this corpus instead of executing herdr, so the
sandbox can deny the IPC socket outright and no eval command can reach the live
session. That makes the corpus a fixture pinned to a herdr version -- rerun this
after upgrading herdr, or `herdr-shim.sh` will refuse newly added subcommands
and `herdr-corpus.test.ts` will fail on the version mismatch.

    ./tests/skill-evals/capture-herdr-help.py
"""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

OUT = Path(__file__).parent / "herdr-help-corpus.json"


def herdr_bin() -> str:
    found = subprocess.run(
        ["bash", "-lc", "command -v herdr"], capture_output=True, text=True
    ).stdout.strip()
    if not found:
        raise SystemExit("herdr not found on PATH")
    return found


def main() -> None:
    real = herdr_bin()
    corpus: dict[str, dict[str, object]] = {}

    def add(args: list[str]) -> str:
        proc = subprocess.run([real, *args], capture_output=True, text=True)
        out = proc.stdout + proc.stderr
        corpus[" ".join(args)] = {"stdout": out, "exit": proc.returncode}
        return out

    def subcommands(out: str) -> list[str]:
        block = re.search(r"^Commands:\n((?:[ \t]+\S.*\n?)+)", out, re.M)
        if not block:
            return []
        return [
            line.split()[0]
            for line in block.group(1).splitlines()
            if line.strip() and not line.strip().startswith("-")
        ]

    top = add(["--help"])
    add(["help"])
    add(["--version"])

    for group in sorted(set(re.findall(r"^\s+herdr (\w[\w-]*) <subcommand>", top, re.M))):
        group_help = add([group, "--help"])
        for sub in subcommands(group_help):
            sub_help = add([group, sub, "--help"])
            for leaf in subcommands(sub_help):
                add([group, sub, leaf, "--help"])

    OUT.write_text(json.dumps(corpus, indent=1, sort_keys=True) + "\n")
    print(f"wrote {OUT.name}: {len(corpus)} entries")


if __name__ == "__main__":
    main()
