#!/usr/bin/env python3
"""Create a Herdr workspace and start Pi with a handoff prompt.

This script is intentionally small and dependency-free so agents can copy or run it
from the skill directory.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path


def run(
    args: list[str], *, input_text: str | None = None, capture: bool = False
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        input=input_text,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
        check=True,
    )


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
        description="Create a Herdr workspace for a repo, launch Pi, and submit a handoff prompt.",
    )
    parser.add_argument(
        "--cwd", required=True, help="Repository/directory for the Herdr workspace"
    )
    parser.add_argument("--label", required=True, help="Herdr workspace label")
    parser.add_argument(
        "--prompt-file",
        required=True,
        help="Markdown/text file containing the Pi handoff prompt",
    )
    parser.add_argument(
        "--agent-name", help="Unique Herdr agent name (default: derived from pane ID)"
    )
    parser.add_argument("--focus", action="store_true", help="Focus the new workspace")
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
        "--focus" if args.focus else "--no-focus",
    ]
    try:
        created = run(create_cmd, capture=True)
        payload = json.loads(created.stdout)
        result = payload["result"]
        pane_id = result["root_pane"]["pane_id"]
        workspace_id = result["workspace"]["workspace_id"]
        agent_name = args.agent_name or agent_name_for_pane(pane_id)

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
                str(args.startup_timeout_ms),
            ],
            capture=True,
        )
        run(["herdr", "agent", "prompt", agent_name, prompt], capture=True)
    except FileNotFoundError:
        print("error: herdr is not installed or not in PATH", file=sys.stderr)
        return 127
    except subprocess.CalledProcessError as error:
        detail = (error.stderr or error.stdout or f"exit {error.returncode}").strip()
        print(f"error: herdr command failed: {detail}", file=sys.stderr)
        return error.returncode
    except (json.JSONDecodeError, KeyError) as error:
        print(
            f"error: Herdr returned an unexpected workspace response: {error}",
            file=sys.stderr,
        )
        return 2

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
