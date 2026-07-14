#!/usr/bin/env python3
"""Inspect or wait on a Herdr pane running a child agent."""

from __future__ import annotations

import argparse
import subprocess


def run(args: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, text=True, check=check)


def main() -> int:
    parser = argparse.ArgumentParser(description="Monitor a Herdr pane by status and recent output.")
    parser.add_argument("--pane", required=True, help="Herdr pane id")
    parser.add_argument(
        "--wait-status",
        choices=["idle", "working", "blocked", "done", "unknown"],
        help="Wait for this agent status before reading output",
    )
    parser.add_argument("--timeout-ms", type=int, default=120_000, help="Wait timeout for --wait-status")
    parser.add_argument("--lines", type=int, default=80, help="Recent lines to read")
    parser.add_argument(
        "--source",
        choices=["visible", "recent", "recent-unwrapped"],
        default="recent",
        help="Herdr pane read source",
    )
    args = parser.parse_args()

    run(["herdr", "pane", "get", args.pane], check=False)

    if args.wait_status:
        run(
            [
                "herdr",
                "wait",
                "agent-status",
                args.pane,
                "--status",
                args.wait_status,
                "--timeout",
                str(args.timeout_ms),
            ],
            check=False,
        )

    run(
        [
            "herdr",
            "pane",
            "read",
            args.pane,
            "--source",
            args.source,
            "--lines",
            str(args.lines),
        ],
        check=False,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
