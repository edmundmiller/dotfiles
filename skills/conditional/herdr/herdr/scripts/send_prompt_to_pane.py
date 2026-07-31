#!/usr/bin/env python3
"""Send a prompt file to an existing Herdr pane and press Enter."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def run(args: list[str]) -> None:
    subprocess.run(args, text=True, check=True)


def default_agent_name(pane_id: str) -> str:
    suffix = "".join(char if char.isalnum() else "_" for char in pane_id)
    return f"pi_{suffix}"[:32]


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
        "--agent-name",
        help="Unique live agent name when --start-pi is used",
    )
    parser.add_argument(
        "--start-timeout-ms",
        type=int,
        default=30_000,
        help="How long agent start waits for Herdr to detect Pi as ready",
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
        agent_name = args.agent_name or default_agent_name(args.pane)
        run(
            [
                "herdr",
                "agent",
                "start",
                agent_name,
                "--kind",
                "pi",
                "--pane",
                args.pane,
                "--timeout",
                str(args.start_timeout_ms),
            ]
        )

    run(["herdr", "agent", "prompt", args.pane, prompt])
    print(args.pane)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
