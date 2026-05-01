#!/usr/bin/env python3
"""Hermes pre_tool_call hook: rewrites terminal commands via RTK."""

import json
import shutil
import subprocess
import sys


def main():
    try:
        payload = json.loads(sys.stdin.read())
    except Exception:
        return

    if payload.get("tool_name") != "terminal":
        return

    tool_input = payload.get("tool_input") or {}
    command = tool_input.get("command")
    if not command:
        return

    if not shutil.which("rtk"):
        return

    try:
        result = subprocess.run(
            ["rtk", "rewrite", command],
            capture_output=True,
            text=True,
            timeout=4,
        )
    except Exception:
        return

    if result.returncode in (1, 2):
        return

    if result.returncode in (0, 3):
        rewritten = result.stdout.strip()
        if rewritten and rewritten != command:
            print(
                json.dumps(
                    {
                        "action": "block",
                        "message": f"RTK rewrite suggested. Re-run as: {rewritten}",
                    }
                )
            )


if __name__ == "__main__":
    main()
