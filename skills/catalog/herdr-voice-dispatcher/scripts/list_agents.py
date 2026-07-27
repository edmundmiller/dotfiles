#!/usr/bin/env python3
"""Print a concise, session-secret-free Herdr agent inventory."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="List live Herdr agents without native session references."
    )
    parser.add_argument(
        "--query",
        help="Case-insensitive filter over pane, agent, status, cwd, and title.",
    )
    return parser.parse_args()


def load_agents() -> list[dict[str, Any]]:
    try:
        result = subprocess.run(
            ["herdr", "agent", "list"],
            check=False,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        raise SystemExit("Error: herdr is not installed or is not on PATH.") from None

    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "unknown error"
        raise SystemExit(f"Error: herdr agent list failed: {detail}")

    try:
        payload = json.loads(result.stdout)
        agents = payload["result"]["agents"]
    except (json.JSONDecodeError, KeyError, TypeError) as error:
        raise SystemExit(f"Error: unexpected Herdr response: {error}") from error

    if not isinstance(agents, list):
        raise SystemExit("Error: unexpected Herdr response: agents is not a list.")
    return agents


def summarize(agent: dict[str, Any]) -> dict[str, Any]:
    return {
        "pane_id": agent.get("pane_id"),
        "agent": agent.get("agent"),
        "status": agent.get("agent_status"),
        "cwd": agent.get("foreground_cwd") or agent.get("cwd"),
        "title": agent.get("terminal_title_stripped")
        or agent.get("terminal_title"),
        "focused": bool(agent.get("focused")),
    }


def matches(agent: dict[str, Any], query: str) -> bool:
    needle = query.casefold()
    return any(needle in str(value).casefold() for value in agent.values())


def main() -> int:
    args = parse_args()
    agents = [summarize(agent) for agent in load_agents()]

    if args.query:
        agents = [agent for agent in agents if matches(agent, args.query)]
        if not agents:
            print(
                json.dumps(
                    {"error": "no matching live Herdr agents", "query": args.query}
                )
            )
            return 1

    print(json.dumps({"agents": agents}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
