#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path


MARKER = ".agent-skills-managed.json"


def main() -> int:
    if len(sys.argv) != 5:
        raise SystemExit(
            "usage: adopt-legacy-agent-skills.py DESTINATION BUNDLE TARGET STRUCTURE"
        )

    destination = Path(sys.argv[1])
    bundle, target, structure = sys.argv[2:]
    if not destination.is_absolute() or not bundle or not target:
        raise SystemExit("destination must be absolute; bundle and target are required")
    if structure not in {"copy-tree", "symlink-tree"}:
        raise SystemExit(f"unsupported structure: {structure}")

    marker = destination / MARKER
    if not destination.is_dir() or destination.is_symlink() or marker.exists():
        return 0

    managed_entries = []
    saw_entries = False
    for entry in destination.rglob("*"):
        saw_entries = True
        relative = entry.relative_to(destination)
        if relative.parts[0] == ".system":
            continue
        managed_entries.append(entry)

    if not saw_entries:
        return 0

    # ponytail: old Nix copy-tree deployments preserve epoch mtimes. If local
    # content breaks that signature, leave the upstream overwrite guard intact.
    if any(
        entry.is_symlink() or entry.stat().st_mtime > 1 for entry in managed_entries
    ):
        return 0

    payload = {
        "schemaVersion": 1,
        "managedBy": "agent-skills-nix",
        "mode": "global",
        "bundle": bundle,
        "target": target,
        "structure": structure,
    }
    temporary = destination / f".{MARKER}.tmp.{os.getpid()}"
    temporary.write_text(json.dumps(payload, sort_keys=True) + "\n")
    temporary.replace(marker)
    print(f"agent-skills: adopted legacy Nix-managed target {destination}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
