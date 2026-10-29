#!/usr/bin/env -S uv run --script
# /// script
# dependencies = []
# ///
"""Create jj task workspaces and reopen their Rex sessions without touching Git-only worktrees."""

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


def run_command(*args, cwd=None):
    """Capture command data; retain the command's diagnostic on failure."""
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(
            result.stderr.strip() or f"{args[0]} exited {result.returncode}"
        )
    return result.stdout.strip()


def workspace_root(path):
    """Require existing jj metadata, including when invoked from a subdirectory."""
    try:
        return Path(
            run_command("jj", "root", "--ignore-working-copy", cwd=path)
        ).resolve()
    except RuntimeError as error:
        raise RuntimeError(
            "rex-jj requires a jj workspace. Git-only worktrees stay Git-only; "
            "initialize jj separately from the primary checkout."
        ) from error


def review_workspace(root):
    """Use Hunk only when Git and jj identify the same child checkout."""
    git = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        cwd=root,
        text=True,
        capture_output=True,
    )
    if (
        git.returncode == 0
        and Path(git.stdout.strip()).resolve() == root
        and shutil.which("hunk")
    ):
        command = ["hunk", "diff", "--no-transparent-bg"]
    else:
        command = ["jj", "--no-pager", "diff", "--git"]
    return subprocess.call(command, cwd=root)


def open_workspace(root, agent):
    """Reuse a recorded live session; preserve the workspace if Rex cannot open it."""
    # Metadata stays outside the tracked tree. Lock serializes concurrent opens.
    with (root / ".jj" / "rex-session.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state_file = root / ".jj" / "rex-session.json"
        state = json.loads(state_file.read_text()) if state_file.exists() else {}
        server = json.loads(run_command("rex", "whoami", "--json"))
        # These commands run on the checkout's host. Never send local paths to a remote server.
        if not server.get("endpoint", "").startswith("unix:"):
            raise RuntimeError(
                "Run rex-jj on the workspace host against its local Rex socket."
            )
        sessions = json.loads(run_command("rex", "ls", "--json"))["sessions"]
        if state.get("endpoint") == server["endpoint"] and any(
            item["session_id"] == state.get("session_id") for item in sessions
        ):
            return state | {"reused": True}

        executable = shutil.which(agent or "")
        if not executable:
            raise RuntimeError(
                "Set AGENT to one executable, or pass --agent PATH. Use a wrapper for flags."
            )
        executable = str(Path(executable).absolute())
        task = run_command(
            "jj",
            "--ignore-working-copy",
            "workspace",
            "list",
            "-T",
            "if(self.target().current_working_copy(), self.name())",
            cwd=root,
        )
        receipt_path = state.get("receiptPath")
        if receipt_path is None:
            receipt = json.loads(
                run_command(
                    "agent-run",
                    "start",
                    "--repo",
                    str(root),
                    "--task",
                    task,
                    "--runtime",
                    agent,
                )
            )
            receipt_path = receipt["receiptPath"]
            # Retain provenance even if opening the Rex session fails.
            state_file.write_text(json.dumps({"receiptPath": receipt_path}) + "\n")

        def window(label, command):
            return {
                "window_label": label,
                "layout": {
                    "block": {
                        "flavor": "com.superlogical.terminal.shell",
                        "options": {
                            "cwd": str(root),
                            "command": command,
                            "exit": {"on_completion": False},
                        },
                    }
                },
            }

        created = json.loads(
            run_command(
                "rex",
                "api",
                "call",
                "session.create",
                json.dumps(
                    {
                        "label": task,
                        "initial_windows": [
                            window(
                                "review",
                                [
                                    sys.executable,
                                    str(Path(__file__).resolve()),
                                    "review",
                                    str(root),
                                ],
                            ),
                            window("agent", [executable]),
                        ],
                    }
                ),
            )
        )
        state = created | {
            "endpoint": server["endpoint"],
            "workspace": str(root),
            "receiptPath": receipt_path,
        }
        state_file.write_text(json.dumps(state, indent=2) + "\n")
        return state | {"reused": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    create = commands.add_parser(
        "new", help="Create an isolated task checkout and its Rex session"
    )
    create.add_argument("task", nargs="?", help="Task slug; prompts only on a terminal")
    create.add_argument("--repo", default=".")
    create.add_argument(
        "--base", help="Starting revision, default trunk(); prompts on a terminal"
    )
    create.add_argument("--agent", default=os.environ.get("AGENT"))
    create.add_argument(
        "--client", help="Select the task session in this Rex app client"
    )
    for name in ("open", "review"):
        sub = commands.add_parser(
            name,
            help="Reopen an existing workspace"
            if name == "open"
            else "Review this workspace",
        )
        sub.add_argument("path", nargs="?", default=".")
        if name == "open":
            sub.add_argument("--agent", default=os.environ.get("AGENT"))
            sub.add_argument(
                "--client", help="Select the task session in this Rex app client"
            )
    args = parser.parse_args()
    try:
        if args.command == "new":
            root = workspace_root(args.repo)
            if not args.task and sys.stdin.isatty():
                print("Task name: ", end="", file=sys.stderr, flush=True)
                args.task = input().strip()
                if not args.base:
                    print("Base [trunk()]: ", end="", file=sys.stderr, flush=True)
                    args.base = input().strip() or "trunk()"
            if not args.task or not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,79}", args.task):
                raise RuntimeError(
                    "Pass a task slug of 1–80 lowercase letters, digits, or hyphens."
                )
            if not shutil.which(args.agent or ""):
                raise RuntimeError(
                    "Set AGENT to one executable, or pass --agent PATH. Use a wrapper for flags."
                )
            # The Git backend path is shared by all jj workspaces, unlike their roots.
            backend = run_command(
                "jj", "git", "root", "--ignore-working-copy", cwd=root
            )
            key = hashlib.sha256(str(Path(backend).resolve()).encode()).hexdigest()[:16]
            data = Path(
                os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))
            )
            destination = data / "rex" / "workspaces" / key / args.task
            bookmarks = run_command(
                "jj", "bookmark", "list", "--all", "-T", 'name ++ "\\n"', cwd=root
            ).splitlines()
            if args.task in bookmarks:
                raise RuntimeError(
                    "Task bookmark already exists. Use rex-jj open PATH to resume; choose another task for new work."
                )
            destination.parent.mkdir(parents=True, exist_ok=True)
            run_command(
                "jj",
                "workspace",
                "add",
                "--name",
                args.task,
                "-r",
                args.base or "trunk()",
                str(destination),
                cwd=root,
            )
            root = destination.resolve()
            print(
                f"Workspace created: {root}. Resume with: rex-jj open '{root}'",
                file=sys.stderr,
            )
            run_command("jj", "bookmark", "create", args.task, "-r", "@", cwd=root)
        else:
            root = workspace_root(args.path)
        if args.command == "review":
            return review_workspace(root)
        state = open_workspace(root, args.agent)
        print(json.dumps(state), flush=True)
        if args.client:
            try:
                run_command(
                    "rex",
                    "-C",
                    args.client,
                    "do",
                    "session.select",
                    f"session_id={state['session_id']}",
                )
            except RuntimeError as error:
                print(
                    f"Session is ready; select it with prefix+w. App selection failed: {error}",
                    file=sys.stderr,
                )
        return 0
    except (RuntimeError, OSError, ValueError, EOFError) as error:
        print(f"rex-jj: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
