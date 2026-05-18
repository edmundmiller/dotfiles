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


def run(args: list[str], *, input_text: str | None = None, capture: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        input=input_text,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
        check=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create a Herdr workspace for a repo, launch Pi, and submit a handoff prompt.",
    )
    parser.add_argument("--cwd", required=True, help="Repository/directory for the Herdr workspace")
    parser.add_argument("--label", required=True, help="Herdr workspace label")
    parser.add_argument("--prompt-file", required=True, help="Markdown/text file containing the Pi handoff prompt")
    parser.add_argument(
        "--no-focus",
        action="store_true",
        help="Create the workspace without focusing it",
    )
    parser.add_argument(
        "--idle-timeout-ms",
        type=int,
        default=30_000,
        help="How long to wait for Pi to become idle before sending the prompt",
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

    run(["herdr", "pane", "run", pane_id, "pi"])

    # Pi can take a moment to initialize. If the wait times out, still try to
    # submit the prompt; some Herdr agent detectors report unknown/idle late.
    subprocess.run(
        [
            "herdr",
            "wait",
            "agent-status",
            pane_id,
            "--status",
            "idle",
            "--timeout",
            str(args.idle_timeout_ms),
        ],
        text=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )

    run(["herdr", "pane", "send-text", pane_id, prompt])
    run(["herdr", "pane", "send-keys", pane_id, "Enter"])

    print(json.dumps({"workspace_id": workspace_id, "pane_id": pane_id}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
