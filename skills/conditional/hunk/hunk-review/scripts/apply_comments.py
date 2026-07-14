#!/usr/bin/env python3
"""Validate a Hunk comment batch and optionally apply it to a live session."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

TARGETS = ("hunk", "hunkNumber", "oldLine", "newLine")
ALLOWED = {"filePath", "summary", *TARGETS}


def positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def validate(payload: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(payload, dict) or set(payload) != {"comments"}:
        return ["top level must be an object containing only 'comments'"]
    comments = payload["comments"]
    if not isinstance(comments, list) or not comments:
        return ["'comments' must be a non-empty array"]

    for index, comment in enumerate(comments):
        prefix = f"comments[{index}]"
        if not isinstance(comment, dict):
            errors.append(f"{prefix} must be an object")
            continue
        unknown = sorted(set(comment) - ALLOWED)
        if unknown:
            errors.append(f"{prefix} has unsupported keys: {', '.join(unknown)}")
        for key in ("filePath", "summary"):
            if not isinstance(comment.get(key), str) or not comment[key].strip():
                errors.append(f"{prefix}.{key} must be a non-empty string")
        targets = [key for key in TARGETS if key in comment]
        if len(targets) != 1:
            errors.append(f"{prefix} must contain exactly one target: {', '.join(TARGETS)}")
        elif not positive_int(comment[targets[0]]):
            errors.append(f"{prefix}.{targets[0]} must be a positive integer")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    selector = parser.add_mutually_exclusive_group()
    selector.add_argument("--repo", default=".", help="Repository path selecting the live session")
    selector.add_argument("--session-id", help="Exact live Hunk session ID")
    parser.add_argument("--check", action="store_true", help="Validate only; do not contact Hunk")
    parser.add_argument("--focus", action="store_true", help="Focus the first applied comment")
    parser.add_argument("file", type=Path, help="JSON file containing {'comments': [...]} ")
    args = parser.parse_args()

    try:
        payload = json.loads(args.file.read_text())
    except OSError as error:
        print(f"error: cannot read {args.file}: {error}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as error:
        print(f"error: invalid JSON in {args.file}: {error}", file=sys.stderr)
        return 2

    errors = validate(payload)
    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        return 2

    if args.check:
        print(f"valid: {len(payload['comments'])} comment(s)")
        return 0

    target = [args.session_id] if args.session_id else ["--repo", args.repo]
    command = ["hunk", "session", "comment", "apply", *target, "--stdin"]
    if args.focus:
        command.append("--focus")

    try:
        subprocess.run(command, input=json.dumps(payload), text=True, check=True)
    except FileNotFoundError:
        print("error: hunk is not installed or not in PATH", file=sys.stderr)
        return 127
    except subprocess.CalledProcessError as error:
        return error.returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
