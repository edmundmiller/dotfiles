#!/usr/bin/env python3
"""Verify that the parent flake carries the child skills input pins."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


def load_lock(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"cannot read {path}: {error}") from error


def resolve_node(lock: dict[str, Any], reference: Any) -> dict[str, Any]:
    if isinstance(reference, str):
        return lock["nodes"][reference]
    if not isinstance(reference, list):
        raise ValueError(f"unsupported lock reference: {reference!r}")
    if not reference:
        raise ValueError("empty lock reference")

    node = lock["nodes"][lock["root"]]
    for input_name in reference:
        next_reference = node["inputs"][input_name]
        node = resolve_node(lock, next_reference)
    return node


def locked_source(lock: dict[str, Any], reference: Any) -> Any:
    node = resolve_node(lock, reference)
    if "locked" not in node:
        raise ValueError(f"input is not pinned: {reference!r}")
    return node["locked"]


def check(repo: Path) -> list[str]:
    child = load_lock(repo / "skills" / "flake.lock")
    parent = load_lock(repo / "flake.lock")
    child_inputs = child["nodes"][child["root"]]["inputs"]
    parent_inputs = parent["nodes"]["skills-catalog"]["inputs"]
    failures: list[str] = []

    child_names = set(child_inputs)
    parent_names = set(parent_inputs)
    if child_names != parent_names:
        missing = sorted(child_names - parent_names)
        extra = sorted(parent_names - child_names)
        if missing:
            failures.append(f"parent is missing child inputs: {', '.join(missing)}")
        if extra:
            failures.append(f"parent has stale child inputs: {', '.join(extra)}")

    for name in sorted(child_names & parent_names):
        parent_reference = parent_inputs[name]
        # Parent follows are intentional overrides (for example nixpkgs).
        if isinstance(parent_reference, list):
            resolve_node(parent, parent_reference)
            continue
        if locked_source(child, child_inputs[name]) != locked_source(parent, parent_reference):
            failures.append(f"parent pin is stale for child input: {name}")

    return failures


def main() -> int:
    repo = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    try:
        failures = check(repo)
    except (KeyError, TypeError, ValueError) as error:
        print(f"ERROR skills-lock-sync: {error}", file=sys.stderr)
        return 1

    if failures:
        print("ERROR skills-lock-sync:", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        print("Run: hey skills-sync", file=sys.stderr)
        return 1

    print("PASS skills-lock-sync")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
