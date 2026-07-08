#!/usr/bin/env python3
"""Dotfiles Herdr dev-layout plugin."""
from __future__ import annotations

import json
import os
import shlex
import shutil
import subprocess
import sys
from typing import Any


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


def context() -> dict[str, Any]:
    raw = os.environ.get("HERDR_PLUGIN_CONTEXT_JSON") or "{}"
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {}


def ctx_worktree_path(ctx: dict[str, Any]) -> str | None:
    worktree = ctx.get("worktree") or {}
    for key in ("checkout_path", "path"):
        value = worktree.get(key)
        if value:
            return str(value)
    return ctx.get("workspace_cwd") or ctx.get("focused_pane_cwd")


def command_exists(command: str) -> bool:
    return shutil.which(command) is not None


def main_coding_agent() -> str:
    agent = (os.environ.get("HERDR_MAIN_CODING_AGENT") or "pi").strip() or "pi"
    if not all(ch.isalnum() or ch in "._-" for ch in agent):
        raise SystemExit(f"invalid HERDR_MAIN_CODING_AGENT: {agent!r}")
    return agent


def git_output(cwd: str, args: list[str]) -> str | None:
    result = subprocess.run(["git", *args], cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    if result.returncode != 0:
        return None
    value = result.stdout.strip()
    return value or None


def default_base_ref(cwd: str) -> str | None:
    for candidate in ("origin/main", "origin/master", "main", "master"):
        if git_output(cwd, ["rev-parse", "--verify", candidate]):
            return candidate
    return None


def macos_dark_mode() -> bool | None:
    if sys.platform != "darwin":
        return None
    result = subprocess.run(
        [
            "osascript",
            "-e",
            'tell application "System Events" to tell appearance preferences to get dark mode',
        ],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode != 0:
        return None
    value = result.stdout.strip().lower()
    if value == "true":
        return True
    if value == "false":
        return False
    return None


def hunk_theme_args() -> list[str]:
    args = ["--no-transparent-bg"]
    if os.environ.get("HUNK_THEME"):
        return ["--theme", os.environ["HUNK_THEME"], *args]
    dark_mode = macos_dark_mode()
    if dark_mode is True:
        return ["--theme", "catppuccin-mocha", *args]
    if dark_mode is False:
        return ["--theme", "catppuccin-latte", *args]
    return args


def hunk_command(cwd: str, mode: str = "worktree", passthrough: list[str] | None = None) -> str:
    executable = "hunk" if command_exists("hunk") else "bunx hunkdiff"
    passthrough = passthrough or []
    args: list[str]
    if mode == "staged":
        args = ["diff", "--staged"]
    elif mode == "branch-committed":
        branch = git_output(cwd, ["branch", "--show-current"]) or "HEAD"
        upstream = git_output(cwd, ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"]) or default_base_ref(cwd) or "origin/main"
        args = ["diff", f"{upstream}..{branch}"]
    else:
        args = ["diff"]
    args.extend(hunk_theme_args())
    args.extend(passthrough)
    return " ".join([executable, *(shlex.quote(arg) for arg in args)])


def response_path(payload: dict[str, Any], *path: str) -> Any:
    cursor: Any = payload
    for part in path:
        cursor = cursor[part]
    return cursor


def tab_create(workspace_id: str, cwd: str, label: str) -> str:
    payload = run_json(["tab", "create", "--workspace", workspace_id, "--cwd", cwd, "--label", label, "--focus"])
    return response_path(payload, "result", "root_pane", "pane_id")


def pane_run(pane_id: str, command: str) -> None:
    run_json(["pane", "run", pane_id, command])


def pane_rename(pane_id: str, label: str) -> None:
    run_json(["pane", "rename", pane_id, label])


def hunk(open_tab: bool, mode: str = "worktree", passthrough: list[str] | None = None) -> None:
    ctx = context()
    cwd = ctx.get("focused_pane_cwd") or ctx.get("workspace_cwd") or os.getcwd()
    workspace_id = ctx.get("workspace_id") or os.environ.get("HERDR_WORKSPACE_ID")
    pane_id = ctx.get("focused_pane_id") or os.environ.get("HERDR_PANE_ID")
    if not workspace_id:
        raise SystemExit("missing Herdr workspace id in plugin context")
    if open_tab:
        target_pane = tab_create(workspace_id, cwd, "hunk")
    else:
        if not pane_id:
            raise SystemExit("missing Herdr pane id in plugin context")
        payload = run_json(["pane", "split", pane_id, "--direction", "right", "--cwd", cwd, "--focus"])
        target_pane = response_path(payload, "result", "pane", "pane_id")
    pane_rename(target_pane, "hunk")
    pane_run(target_pane, hunk_command(cwd, mode, passthrough))


def bootstrap() -> None:
    ctx = context()
    workspace_id = ctx.get("workspace_id") or os.environ.get("HERDR_WORKSPACE_ID")
    cwd = ctx_worktree_path(ctx) or os.getcwd()
    if not workspace_id:
        raise SystemExit("missing Herdr workspace id in plugin context")

    agent = main_coding_agent()
    if command_exists(agent):
        pane = tab_create(workspace_id, cwd, agent)
        pane_rename(pane, agent)
        pane_run(pane, agent)
    pane = tab_create(workspace_id, cwd, "hunk")
    pane_rename(pane, "hunk")
    pane_run(pane, hunk_command(cwd))

    if command_exists("nvim"):
        pane = tab_create(workspace_id, cwd, "nvim")
        pane_rename(pane, "nvim")
        pane_run(pane, "nvim .")

    shell_pane = tab_create(workspace_id, cwd, "shell")
    pane_rename(shell_pane, "shell")

    # When invoked by the worktree.created event, close the initial empty tab.
    if os.environ.get("HERDR_PLUGIN_EVENT") == "worktree.created":
        tab_id = ctx.get("tab_id") or os.environ.get("HERDR_TAB_ID")
        pane_id = ctx.get("focused_pane_id") or os.environ.get("HERDR_PANE_ID")
        if tab_id:
            subprocess.run([herdr_bin(), "tab", "close", tab_id], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif pane_id:
            subprocess.run([herdr_bin(), "pane", "close", pane_id], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    run_json(["workspace", "focus", workspace_id])


def main() -> None:
    args = sys.argv[1:]
    if args and args[0] == "hunk":
        open_tab = "--tab" in args
        mode = "branch-committed" if "--branch-committed" in args else "staged" if any(a in args for a in ("--staged", "--cached")) else "worktree"
        passthrough = args[args.index("--") + 1 :] if "--" in args else []
        hunk(open_tab=open_tab, mode=mode, passthrough=passthrough)
    else:
        bootstrap()


if __name__ == "__main__":
    main()
