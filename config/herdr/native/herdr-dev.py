#!/usr/bin/env python3
"""Open native Herdr dev spaces; never create or remove jj workspaces.

Nix wraps this stdlib-only script as herdr-dev. Hunk reviews the invoking
shell's working directory, beside the window's focused local model pane.
"""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys


class HerdrDevError(Exception):
    """A failed preflight or app request; no automatic UI cleanup is safe."""


def run_command(argv, cwd=None):
    """Run an external command without shell interpolation."""
    try:
        result = subprocess.run(argv, cwd=cwd, text=True, capture_output=True)
    except OSError as error:
        raise HerdrDevError(f"Cannot run {argv[0]}: {error}") from error
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise HerdrDevError(f"{argv[0]} exited {result.returncode}: {detail}")
    return result.stdout


def app_request(*args, required=()):
    """Parse native app replies, including errors returned with exit code zero."""
    output = run_command([os.environ.get("HERDR_APP_COMMAND", "herdr-app"), *args])
    try:
        reply = json.loads(output)
    except ValueError as error:
        raise HerdrDevError(f"Invalid Herdr JSON reply: {output.strip()}") from error
    if not isinstance(reply, dict):
        raise HerdrDevError(f"Invalid Herdr object reply: {reply!r}")
    if reply.get("error"):
        raise HerdrDevError(f"Herdr request failed: {reply['error']}")
    for key in required:
        if not isinstance(reply.get(key), str) or not reply[key].strip():
            raise HerdrDevError(f"Herdr reply missing {key} id: {reply!r}")
    return reply


def validate_repository(folder):
    """Require a real Git working directory, including existing jj colocated repos."""
    folder = Path(folder).expanduser().resolve()
    if not folder.is_dir():
        raise HerdrDevError(f"Invalid folder: {folder}")
    if (
        run_command(["git", "rev-parse", "--is-inside-work-tree"], cwd=folder).strip()
        != "true"
    ):
        raise HerdrDevError(f"Not a Git working directory: {folder}")
    return folder


def prepare_qmd(folder):
    """Run the YAML's optional executable qmd seed hook before any UI mutation."""
    script = folder / "scripts" / "qmd-seed-worktree.sh"
    if script.is_file() and os.access(script, os.X_OK):
        output = run_command([str(script)], cwd=folder)
        if output:
            print(output, end="" if output.endswith("\n") else "\n", file=sys.stderr)


def hunk_argv(folder, diff_args):
    """Keep review arguments as argv, including refs and folders with shell syntax."""
    return [
        "sh",
        "-c",
        'cd "$1" || exit; shift; if command -v hunk >/dev/null 2>&1; '
        'then exec hunk diff --no-transparent-bg "$@"; '
        'else exec bunx hunkdiff diff --no-transparent-bg "$@"; fi',
        "herdr-dev-hunk",
        str(folder),
        *diff_args,
    ]


def open_dev_space(folder, agent):
    """Create an agent space and Hunk tab; retain all resources on partial failure."""
    folder = validate_repository(folder)
    prepare_qmd(folder)
    made = {}
    try:
        made = app_request(
            "do",
            "space.new",
            json.dumps(
                {
                    "folder": str(folder),
                    "tab": agent,
                    "argv": [agent],
                }
            ),
            required=("space", "tab", "terminal"),
        )
        review = app_request(
            "do",
            "tab.new",
            json.dumps(
                {
                    "space": made["space"],
                    "name": "hunk",
                    "folder": str(folder),
                    "argv": hunk_argv(folder, []),
                }
            ),
            required=("tab", "terminal"),
        )
    except HerdrDevError as error:
        resources = json.dumps(made) if made else "ids unavailable"
        raise HerdrDevError(
            f"Open incomplete ({resources}): {error}. "
            "UI may have changed; nothing was closed or removed. Inspect herdr-app ls before retrying."
        ) from error
    print(json.dumps({"agent": made, "hunk": review}))


def open_hunk_split(staged, branch, pane=None):
    """Review beside a captured pane, or capture focus once for standalone calls."""
    folder = validate_repository(Path.cwd())
    diff_args = ["--staged"] if staged else []
    if branch is not None:
        # Hunk takes a positional target, not --branch. Reject option-like refs.
        if not branch or branch.startswith("-"):
            raise HerdrDevError(
                "Invalid branch base: expected a Git revision, not an option"
            )
        run_command(
            ["git", "rev-parse", "--verify", "--end-of-options", branch + "^{commit}"],
            cwd=folder,
        )
        diff_args = [branch]
    if pane is None:
        pane = app_request("status", required=("focused_pane",))["focused_pane"]
    listing = app_request("ls")
    matches = [
        space
        for space in listing.get("spaces", [])
        if any(
            terminal.get("pane") == pane
            for tab in space.get("tabs", [])
            for terminal in tab.get("terminals", [])
        )
    ]
    if len(matches) != 1 or matches[0].get("machine") is not None:
        raise HerdrDevError(
            "Hunk requires a focused local terminal pane; remote/composition panes are unsupported"
        )
    try:
        reply = app_request(
            "do",
            "pane.split",
            json.dumps(
                {
                    "pane": pane,
                    "direction": "right",
                    "argv": hunk_argv(folder, diff_args),
                }
            ),
            required=("pane", "terminal"),
        )
    except HerdrDevError as error:
        raise HerdrDevError(
            f"Hunk split incomplete: {error}. UI may have changed; nothing was closed or removed."
        ) from error
    print(json.dumps(reply))


def main():
    """Expose only open and hunk; guarded native jj lifecycle is not ported."""
    parser = argparse.ArgumentParser(
        prog="herdr-dev",
        description="Native agent + Hunk workflow (default agent: omp).",
        epilog="jj workspace creation/removal is unsupported; open an existing Git checkout instead.",
    )
    commands = parser.add_subparsers(dest="command", required=True)
    opening = commands.add_parser(
        "open", help="Open an existing Git folder after optional qmd setup"
    )
    opening.add_argument("folder")
    opening.add_argument(
        "--agent", choices=("pi", "omp", "claude", "codex", "opencode"), default="omp"
    )
    hunk = commands.add_parser(
        "hunk", help="Review the invoking Git cwd beside the focused local pane"
    )
    hunk.add_argument(
        "--pane", help="Captured local pane ID, independent of current focus"
    )
    mode = hunk.add_mutually_exclusive_group()
    mode.add_argument("--staged", action="store_true")
    mode.add_argument(
        "--branch", metavar="BASE", help="Compare against a Git commit/ref"
    )
    args = parser.parse_args()
    try:
        if args.command == "open":
            open_dev_space(args.folder, args.agent)
        else:
            open_hunk_split(args.staged, args.branch, args.pane)
    except HerdrDevError as error:
        print(f"herdr-dev: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
