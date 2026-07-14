#!/usr/bin/env python3
"""Print bounded metadata, transcript, and detection evidence for one Herdr agent."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from typing import Any


def run(*args: str, json_output: bool = False) -> Any:
    completed = subprocess.run(
        ["herdr", *args],
        check=True,
        text=True,
        capture_output=True,
    )
    if json_output:
        return json.loads(completed.stdout)
    return completed.stdout.rstrip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", help="Unique agent name, label, or pane ID")
    parser.add_argument("--lines", type=int, default=80, help="Recent transcript lines (default: 80)")
    args = parser.parse_args()

    if args.lines < 1 or args.lines > 500:
        parser.error("--lines must be between 1 and 500")

    try:
        payload = {
            "agent": run("agent", "get", args.target, json_output=True),
            "recent": run(
                "agent",
                "read",
                args.target,
                "--source",
                "recent-unwrapped",
                "--lines",
                str(args.lines),
            ),
            "explain": run("agent", "explain", args.target, "--json", json_output=True),
        }
    except FileNotFoundError:
        print("error: herdr is not installed or not in PATH", file=sys.stderr)
        return 127
    except subprocess.CalledProcessError as error:
        detail = error.stderr.strip() or error.stdout.strip() or f"exit {error.returncode}"
        print(f"error: herdr command failed: {detail}", file=sys.stderr)
        return error.returncode
    except json.JSONDecodeError as error:
        print(f"error: herdr returned invalid JSON: {error}", file=sys.stderr)
        return 2

    json.dump(payload, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
