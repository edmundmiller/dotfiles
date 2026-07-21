#!/usr/bin/env python3
"""Inspect or wait on a Herdr pane running a child agent."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys


def run(args: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, text=True, check=check)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Monitor a Herdr pane by status and recent output."
    )
    parser.add_argument("--pane", required=True, help="Herdr pane id")
    parser.add_argument(
        "--wait-status",
        choices=["idle", "working", "blocked", "done", "unknown"],
        help="Wait for this agent status before reading output",
    )
    parser.add_argument(
        "--timeout-ms", type=int, default=120_000, help="Wait timeout for --wait-status"
    )
    parser.add_argument("--lines", type=int, default=80, help="Recent lines to read")
    parser.add_argument(
        "--source",
        choices=["visible", "recent", "recent-unwrapped", "detection"],
        default="recent",
        help="Herdr agent read source",
    )
    args = parser.parse_args()

    if os.environ.get("HERDR_ENV") != "1":
        print(
            "error: this helper requires HERDR_ENV=1 in a Herdr-managed pane",
            file=sys.stderr,
        )
        return 2

    if args.timeout_ms < 1:
        parser.error("--timeout-ms must be positive")
    if args.lines < 1 or args.lines > 500:
        parser.error("--lines must be between 1 and 500")

    try:
        inspected = run(["herdr", "agent", "get", args.pane], check=False)

        waited = None
        if args.wait_status:
            waited = run(
                [
                    "herdr",
                    "agent",
                    "wait",
                    args.pane,
                    "--until",
                    args.wait_status,
                    "--timeout",
                    str(args.timeout_ms),
                ],
                check=False,
            )

        read = run(
            [
                "herdr",
                "agent",
                "read",
                args.pane,
                "--source",
                args.source,
                "--lines",
                str(args.lines),
            ],
            check=False,
        )
    except FileNotFoundError:
        print("error: herdr is not installed or not in PATH", file=sys.stderr)
        return 127

    for result in (inspected, waited, read):
        if result is not None and result.returncode != 0:
            return result.returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
