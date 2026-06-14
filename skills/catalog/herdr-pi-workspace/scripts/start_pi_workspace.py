#!/usr/bin/env python3
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


def wait_for_pi_ready(pane_id: str, *, ready_timeout_ms: int, idle_timeout_ms: int) -> None:
    """Best-effort wait until Pi has painted its TUI and reported idle.

    `herdr pane run` returns as soon as the shell command is submitted. If we paste a
    long handoff before Pi owns the terminal, the prompt can leak into the shell or
    land in the TUI before it is ready to submit. Waiting for a stable startup line
    first makes the following send-text + Enter handoff much more reliable.
    """

    subprocess.run(
        [
            "herdr",
            "wait",
            "output",
            pane_id,
            "--match",
            "Pi can explain its own features",
            "--source",
            "recent",
            "--lines",
            "120",
            "--timeout",
            str(ready_timeout_ms),
        ],
        text=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )

    subprocess.run(
        [
            "herdr",
            "wait",
            "agent-status",
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
        "--ready-timeout-ms",
        type=int,
        default=30_000,
        help="How long to wait for Pi startup output before sending the prompt",
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
    wait_for_pi_ready(
        pane_id,
        ready_timeout_ms=args.ready_timeout_ms,
        idle_timeout_ms=args.idle_timeout_ms,
    )

    run(["herdr", "pane", "send-text", pane_id, prompt])
    run(["herdr", "pane", "send-keys", pane_id, "Enter"])

    print(json.dumps({"workspace_id": workspace_id, "pane_id": pane_id}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
