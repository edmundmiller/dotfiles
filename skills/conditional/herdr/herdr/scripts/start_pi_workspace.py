#!/usr/bin/env python3
"""Create a Herdr workspace and start Pi with a handoff prompt.

This script is intentionally small and dependency-free so agents can copy or run it
from the skill directory.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


def run(
    args: list[str], *, capture: bool = False
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
        check=True,
    )


def default_agent_name(pane_id: str) -> str:
    suffix = "".join(char if char.isalnum() else "_" for char in pane_id)
    return f"pi_{suffix}"[:32]


def start_pi(pane_id: str, agent_name: str, *, timeout_ms: int) -> None:
    run(
        [
            "herdr",
            "agent",
            "start",
            agent_name,
            "--kind",
            "pi",
            "--pane",
            pane_id,
            "--timeout",
            str(timeout_ms),
        ],
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create a Herdr workspace for a repo, launch Pi, and submit a handoff prompt.",
    )
    parser.add_argument("--cwd", required=True, help="Repository/directory for the Herdr workspace")
    parser.add_argument("--label", required=True, help="Herdr workspace label")
    parser.add_argument("--prompt-file", required=True, help="Markdown/text file containing the Pi handoff prompt")
    parser.add_argument(
        "--agent-name",
        help="Unique live agent name; defaults to one derived from the returned pane ID",
    )
    parser.add_argument(
        "--no-focus",
        action="store_true",
        help="Create the workspace without focusing it",
    )
    parser.add_argument(
        "--start-timeout-ms",
        type=int,
        default=30_000,
        help="How long agent start waits for Herdr to detect Pi as ready",
    )
    args = parser.parse_args()

    cwd = Path(args.cwd).expanduser().resolve()
    prompt_file = Path(args.prompt_file).expanduser().resolve()

    if not cwd.exists() or not cwd.is_dir():
        print(f"error: --cwd is not a directory: {cwd}", file=sys.stderr)
        return 2
    if not prompt_file.exists() or not prompt_file.is_file():
        print(f"error: --prompt-file is not a file: {prompt_file}", file=sys.stderr)
        return 2

    prompt = prompt_file.read_text()
    if not prompt.strip():
        print(f"error: prompt file is empty: {prompt_file}", file=sys.stderr)
        return 2

    create_cmd = [
        "herdr",
        "workspace",
        "create",
        "--cwd",
        str(cwd),
        "--label",
        args.label,
        "--no-focus" if args.no_focus else "--focus",
    ]
    created = run(create_cmd, capture=True)
    payload = json.loads(created.stdout)
    result = payload["result"]
    pane_id = result["root_pane"]["pane_id"]
    workspace_id = result["workspace"]["workspace_id"]
    agent_name = args.agent_name or default_agent_name(pane_id)

    start_pi(pane_id, agent_name, timeout_ms=args.start_timeout_ms)
    run(["herdr", "agent", "prompt", pane_id, prompt])

    print(
        json.dumps(
            {
                "workspace_id": workspace_id,
                "pane_id": pane_id,
                "agent_name": agent_name,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
