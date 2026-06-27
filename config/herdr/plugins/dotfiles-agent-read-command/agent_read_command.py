#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shlex
import shutil
import subprocess
import sys
from typing import Any

DEFAULT_SOURCE = "recent-unwrapped"
DEFAULT_LINES = 200
DEFAULT_FORMAT = "text"


def context() -> dict[str, Any]:
    try:
        raw = os.environ.get("HERDR_PLUGIN_CONTEXT_JSON") or "{}"
        value = json.loads(raw)
        return value if isinstance(value, dict) else {}
    except json.JSONDecodeError:
        return {}


def herdr_bin() -> str:
    return os.environ.get("HERDR_BIN_PATH") or "herdr"


def run_json(args: list[str]) -> dict[str, Any]:
    result = subprocess.run([herdr_bin(), *args], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != 0:
        raise SystemExit(result.stderr or result.stdout or f"herdr {' '.join(args)} failed")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as err:
        raise SystemExit(f"herdr {' '.join(args)} did not return JSON: {err}\n{result.stdout}") from err
    if "error" in payload:
        raise SystemExit(json.dumps(payload["error"], indent=2))
    return payload


def first_string(*values: Any) -> str | None:
    for value in values:
        if isinstance(value, str) and value:
            return value
    return None


def nested_string(data: dict[str, Any], *path: str) -> str | None:
    cursor: Any = data
    for key in path:
        if not isinstance(cursor, dict):
            return None
        cursor = cursor.get(key)
    return cursor if isinstance(cursor, str) and cursor else None


def pane_target(ctx: dict[str, Any]) -> str | None:
    return first_string(
        nested_string(ctx, "agent", "terminal_id"),
        nested_string(ctx, "pane", "terminal_id"),
        nested_string(ctx, "agent", "pane_id"),
        nested_string(ctx, "pane", "pane_id"),
        nested_string(ctx, "pane", "id"),
        ctx.get("focused_pane_id"),
        ctx.get("pane_id"),
        os.environ.get("HERDR_PANE_ID"),
    )


def tab_id(ctx: dict[str, Any]) -> str | None:
    return first_string(
        nested_string(ctx, "tab", "tab_id"),
        nested_string(ctx, "tab", "id"),
        ctx.get("tab_id"),
        os.environ.get("HERDR_TAB_ID"),
    )


def tab_context_target(ctx: dict[str, Any]) -> str | None:
    agent = ctx.get("agent")
    if isinstance(agent, dict):
        target = first_string(agent.get("terminal_id"), agent.get("pane_id"), agent.get("name"), agent.get("agent"))
        if target:
            return target
    tab = ctx.get("tab")
    if isinstance(tab, dict):
        target = first_string(tab.get("active_pane_id"), tab.get("root_pane_id"), tab.get("pane_id"))
        if target:
            return target
    return None


def agent_sort_key(agent: dict[str, Any]) -> tuple[int, str]:
    status = str(agent.get("agent_status") or "")
    priority = {"blocked": 0, "working": 1, "done": 2, "idle": 3, "unknown": 4}.get(status, 5)
    return (priority, str(agent.get("pane_id") or ""))


def tab_target(ctx: dict[str, Any]) -> str | None:
    target = tab_context_target(ctx)
    if target:
        return target
    current_tab_id = tab_id(ctx)
    if not current_tab_id:
        return None
    payload = run_json(["agent", "list"])
    agents = payload.get("result", {}).get("agents", [])
    if not isinstance(agents, list):
        return None
    matches = [agent for agent in agents if isinstance(agent, dict) and agent.get("tab_id") == current_tab_id]
    if not matches:
        return None
    matches.sort(key=agent_sort_key)
    return first_string(matches[0].get("terminal_id"), matches[0].get("pane_id"), matches[0].get("agent"))


def build_command(target: str, source: str = DEFAULT_SOURCE, lines: int = DEFAULT_LINES, output_format: str = DEFAULT_FORMAT) -> str:
    args = ["herdr", "agent", "read", target, "--source", source, "--lines", str(lines), "--format", output_format]
    return " ".join(shlex.quote(arg) for arg in args)


def copy_command(command: str) -> bool:
    candidates = [
        ("pbcopy", ["pbcopy"]),
        ("wl-copy", ["wl-copy"]),
        ("xclip", ["xclip", "-selection", "clipboard"]),
    ]
    for executable, args in candidates:
        if shutil.which(executable):
            result = subprocess.run(args, input=command, text=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return result.returncode == 0
    return False


def notify(command: str, copied: bool) -> None:
    title = "Copied agent read command" if copied else "Agent read command"
    subprocess.run(
        [herdr_bin(), "notification", "show", title, "--body", command, "--position", "top-right", "--sound", "none"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "pane"
    ctx = context()
    target = tab_target(ctx) if mode == "tab" else pane_target(ctx)
    if not target:
        raise SystemExit(f"could not resolve {mode} agent target")
    command = build_command(target)
    copied = copy_command(command)
    notify(command, copied)
    print(command)


if __name__ == "__main__":
    main()
