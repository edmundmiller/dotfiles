#!/usr/bin/env python3
"""Dotfiles Herdr dev-layout plugin."""

from __future__ import annotations
import contextlib
import fcntl
import hashlib
import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
from collections.abc import Iterator
from typing import Any


def herdr_bin() -> str:
    return os.environ.get("HERDR_BIN_PATH") or "herdr"


def run(args: list[str]) -> str:
    result = subprocess.run(
        [herdr_bin(), *args], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    if result.returncode != 0:
        raise SystemExit(
            result.stderr or result.stdout or f"herdr {' '.join(args)} failed"
        )
    return result.stdout


def run_json(args: list[str]) -> dict[str, Any]:
    output = run(args)
    try:
        payload = json.loads(output)
    except json.JSONDecodeError as err:
        raise SystemExit(
            f"herdr {' '.join(args)} did not return JSON: {err}\n{output}"
        ) from err
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


def git_output(cwd: str, args: list[str]) -> str | None:
    result = subprocess.run(
        ["git", *args],
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
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
    dark_theme = os.environ.get("HUNK_THEME_DARK", "catppuccin-mocha")
    light_theme = os.environ.get("HUNK_THEME_LIGHT", "catppuccin-latte")
    dark_mode = macos_dark_mode()
    if dark_mode is True and dark_theme:
        return ["--theme", dark_theme, *args]
    if dark_mode is False and light_theme:
        return ["--theme", light_theme, *args]
    return args


def hunk_command(
    cwd: str, mode: str = "worktree", passthrough: list[str] | None = None
) -> str:
    executable = "hunk" if command_exists("hunk") else "bunx hunkdiff"
    passthrough = passthrough or []
    args: list[str]
    if mode == "staged":
        args = ["diff", "--staged"]
    elif mode == "branch-committed":
        branch = git_output(cwd, ["branch", "--show-current"]) or "HEAD"
        upstream = (
            git_output(
                cwd,
                ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"],
            )
            or default_base_ref(cwd)
            or "origin/main"
        )
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


def tab_create(workspace_id: str, cwd: str, label: str) -> tuple[str, str]:
    payload = run_json(
        ["tab", "create", "--workspace", workspace_id, "--cwd", cwd, "--label", label]
    )
    return response_path(payload, "result", "tab", "tab_id"), response_path(
        payload, "result", "root_pane", "pane_id"
    )


def workspace_tabs(workspace_id: str) -> tuple[dict[str, str], set[str]]:
    payload = run_json(["tab", "list", "--workspace", workspace_id])
    tabs = response_path(payload, "result", "tabs")
    by_label = {
        tab["label"]: tab["tab_id"]
        for tab in tabs
        if tab.get("label") and tab.get("tab_id")
    }
    return by_label, {tab["tab_id"] for tab in tabs if tab.get("tab_id")}


def pane_run(pane_id: str, command: str) -> None:
    run(["pane", "run", pane_id, command])


def pane_rename(pane_id: str, label: str) -> None:
    run_json(["pane", "rename", pane_id, label])


def hunk(
    open_tab: bool, mode: str = "worktree", passthrough: list[str] | None = None
) -> None:
    ctx = context()
    cwd = ctx.get("focused_pane_cwd") or ctx.get("workspace_cwd") or os.getcwd()
    workspace_id = ctx.get("workspace_id") or os.environ.get("HERDR_WORKSPACE_ID")
    pane_id = ctx.get("focused_pane_id") or os.environ.get("HERDR_PANE_ID")
    if not workspace_id:
        raise SystemExit("missing Herdr workspace id in plugin context")
    if open_tab:
        _, target_pane = tab_create(workspace_id, cwd, "hunk")
    else:
        if not pane_id:
            raise SystemExit("missing Herdr pane id in plugin context")
        payload = run_json(
            ["pane", "split", pane_id, "--direction", "right", "--cwd", cwd, "--focus"]
        )
        target_pane = response_path(payload, "result", "pane", "pane_id")
    pane_rename(target_pane, "hunk")
    pane_run(target_pane, hunk_command(cwd, mode, passthrough))


@contextlib.contextmanager
def workspace_lock(workspace_id: str) -> Iterator[None]:
    digest = hashlib.sha256(workspace_id.encode()).hexdigest()
    path = os.path.join(tempfile.gettempdir(), f"herdr-dev-layout-{digest}.lock")
    with open(path, "a+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def bootstrap_workspace(ctx: dict[str, Any], workspace_id: str, cwd: str) -> None:
    tabs, tab_ids = workspace_tabs(workspace_id)
    omp_tab = tabs.get("omp")
    if not omp_tab:
        omp_tab, pane = tab_create(workspace_id, cwd, "omp")
        pane_rename(pane, "omp")
        pane_run(pane, "omp")

    if "hunk" not in tabs:
        _, pane = tab_create(workspace_id, cwd, "hunk")
        pane_rename(pane, "hunk")
        pane_run(pane, hunk_command(cwd))

    event = os.environ.get("HERDR_PLUGIN_EVENT")
    initial_tab = ctx.get("tab_id") or os.environ.get("HERDR_TAB_ID")
    if (
        event in {"workspace.created", "worktree.created"}
        and initial_tab in tab_ids
        and initial_tab not in {omp_tab, tabs.get("hunk")}
    ):
        run_json(["tab", "close", initial_tab])

    run_json(["tab", "focus", omp_tab])


def bootstrap() -> None:
    ctx = context()
    workspace_id = ctx.get("workspace_id") or os.environ.get("HERDR_WORKSPACE_ID")
    cwd = ctx_worktree_path(ctx) or os.getcwd()
    if not workspace_id:
        raise SystemExit("missing Herdr workspace id in plugin context")
    if not command_exists("omp"):
        raise SystemExit("omp not found on PATH")

    with workspace_lock(workspace_id):
        bootstrap_workspace(ctx, workspace_id, cwd)


def main() -> None:
    args = sys.argv[1:]
    if args and args[0] == "hunk":
        open_tab = "--tab" in args
        mode = (
            "branch-committed"
            if "--branch-committed" in args
            else "staged"
            if any(a in args for a in ("--staged", "--cached"))
            else "worktree"
        )
        passthrough = args[args.index("--") + 1 :] if "--" in args else []
        hunk(open_tab=open_tab, mode=mode, passthrough=passthrough)
    else:
        bootstrap()


if __name__ == "__main__":
    main()
