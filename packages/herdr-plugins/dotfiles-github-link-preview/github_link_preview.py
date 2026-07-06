#!/usr/bin/env python3
"""Open a GitHub issue or PR URL in a Herdr side pane using gh."""
from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
from typing import Any

URL_RE = re.compile(r"^https://github\.com/[^/]+/[^/]+/(?P<kind>issues|pull)/[0-9]+(?:[#?].*)?$")


def herdr_bin() -> str:
    return os.environ.get("HERDR_BIN_PATH") or "herdr"


def run_json(args: list[str]) -> dict[str, Any]:
    result = subprocess.run([herdr_bin(), *args], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != 0:
        raise SystemExit(result.stderr or result.stdout or f"herdr {' '.join(args)} failed")
    payload = json.loads(result.stdout)
    if "error" in payload:
        raise SystemExit(json.dumps(payload["error"], indent=2))
    return payload


def context() -> dict[str, Any]:
    try:
        return json.loads(os.environ.get("HERDR_PLUGIN_CONTEXT_JSON") or "{}")
    except json.JSONDecodeError:
        return {}


def response_path(payload: dict[str, Any], *path: str) -> Any:
    cursor: Any = payload
    for part in path:
        cursor = cursor[part]
    return cursor


def main() -> None:
    ctx = context()
    url = os.environ.get("HERDR_PLUGIN_CLICKED_URL") or ctx.get("clicked_url")
    if not url:
        raise SystemExit("missing clicked GitHub URL")
    match = URL_RE.match(url)
    if not match:
        raise SystemExit(f"not a supported GitHub issue/PR URL: {url}")

    pane_id = ctx.get("focused_pane_id") or os.environ.get("HERDR_PANE_ID")
    cwd = ctx.get("focused_pane_cwd") or ctx.get("workspace_cwd") or os.getcwd()
    if not pane_id:
        raise SystemExit("missing focused Herdr pane id in plugin context")

    payload = run_json(["pane", "split", pane_id, "--direction", "right", "--cwd", cwd, "--focus"])
    preview_pane = response_path(payload, "result", "pane", "pane_id")
    run_json(["pane", "rename", preview_pane, "gh-preview"])
    subcommand = "pr" if match.group("kind") == "pull" else "issue"
    command = f"gh {subcommand} view {shlex.quote(url)} --comments"
    run_json(["pane", "run", preview_pane, command])


if __name__ == "__main__":
    main()
