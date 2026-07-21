#!/usr/bin/env python3
"""Start or prompt Pi in an existing Herdr pane through the agent facade."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path


def run(args: list[str]) -> None:
    subprocess.run(args, text=True, check=True, capture_output=True)


def timeout_ms(value: str) -> int:
    parsed = int(value)
    if parsed <= 3_000 or parsed > 300_000:
        raise argparse.ArgumentTypeError(
            "timeout must be greater than 3000 and at most 300000 ms"
        )
    return parsed


def agent_name_for_pane(pane_id: str) -> str:
    suffix = re.sub(r"[^a-z0-9_-]+", "-", pane_id.lower()).strip("-_")
    return f"pi-{suffix}"[:32].rstrip("-_") or "pi-helper"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Submit a handoff prompt to an existing Herdr pane."
    )
    parser.add_argument(
        "--pane", required=True, help="Opaque Herdr pane ID returned by the live server"
    )
    parser.add_argument("--prompt-file", required=True, help="Prompt file to send")
    parser.add_argument(
        "--agent-name", help="Unique live agent name (default: pane ID or derived name)"
    )
    parser.add_argument(
        "--start-pi",
        action="store_true",
        help="Run `pi` in the pane before sending the prompt",
    )
    parser.add_argument(
        "--startup-timeout-ms",
        type=timeout_ms,
        default=30_000,
        help="How long Herdr may wait for Pi startup (default: 30000)",
    )
    args = parser.parse_args()

    if os.environ.get("HERDR_ENV") != "1":
        print(
            "error: this helper requires HERDR_ENV=1 in a Herdr-managed pane",
            file=sys.stderr,
        )
        return 2

    prompt_file = Path(args.prompt_file).expanduser().resolve()
    if not prompt_file.exists() or not prompt_file.is_file():
        print(f"error: --prompt-file is not a file: {prompt_file}", file=sys.stderr)
        return 2
    prompt = prompt_file.read_text()
    if not prompt.strip():
        print(f"error: prompt file is empty: {prompt_file}", file=sys.stderr)
        return 2

    target = args.agent_name or args.pane
    try:
        if args.start_pi:
            target = args.agent_name or agent_name_for_pane(args.pane)
            run(
                [
                    "herdr",
                    "agent",
                    "start",
                    target,
                    "--kind",
                    "pi",
                    "--pane",
                    args.pane,
                    "--timeout",
                    str(args.startup_timeout_ms),
                ]
            )

        run(["herdr", "agent", "prompt", target, prompt])
    except FileNotFoundError:
        print("error: herdr is not installed or not in PATH", file=sys.stderr)
        return 127
    except subprocess.CalledProcessError as error:
        detail = (error.stderr or error.stdout or f"exit {error.returncode}").strip()
        print(f"error: herdr command failed: {detail}", file=sys.stderr)
        return error.returncode

    print(args.pane)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
