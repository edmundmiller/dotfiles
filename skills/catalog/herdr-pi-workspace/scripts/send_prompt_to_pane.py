#!/usr/bin/env python3
"""Send a prompt file to an existing Herdr pane and press Enter."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def run(args: list[str]) -> None:
    subprocess.run(args, text=True, check=True)


def wait_for_pi_ready(pane_id: str, *, idle_timeout_ms: int) -> None:
    """Best-effort wait for Herdr's semantic Pi idle state."""

    subprocess.run(
        [
            "herdr",
            "agent",
            "wait",
            pane_id,
            "--status",
            "idle",
            "--timeout",
            str(idle_timeout_ms),
        ],
        text=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Submit a handoff prompt to an existing Herdr pane.")
    parser.add_argument("--pane", required=True, help="Opaque Herdr pane ID returned by the live server")
    parser.add_argument("--prompt-file", required=True, help="Prompt file to send")
    parser.add_argument(
        "--start-pi",
        action="store_true",
        help="Run `pi` in the pane before sending the prompt",
    )
    parser.add_argument(
        "--idle-timeout-ms",
        type=int,
        default=30_000,
        help="How long to wait for Pi to become idle if --start-pi is used",
    )
    args = parser.parse_args()

    prompt_file = Path(args.prompt_file).expanduser().resolve()
    if not prompt_file.exists() or not prompt_file.is_file():
        print(f"error: --prompt-file is not a file: {prompt_file}", file=sys.stderr)
        return 2
    prompt = prompt_file.read_text()
    if not prompt.strip():
        print(f"error: prompt file is empty: {prompt_file}", file=sys.stderr)
        return 2

    if args.start_pi:
        run(["herdr", "pane", "run", args.pane, "pi"])
        wait_for_pi_ready(args.pane, idle_timeout_ms=args.idle_timeout_ms)

    run(["herdr", "pane", "send-text", args.pane, prompt])
    run(["herdr", "pane", "send-keys", args.pane, "Enter"])
    print(args.pane)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
