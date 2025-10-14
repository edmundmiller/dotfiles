#!/usr/bin/env -S uv run --script
# /// script
# dependencies = []
# [tool.uv]
# exclude-newer = "2025-08-23T00:00:00Z"
# ///
"""
Git to JJ Command Translator

Intercepts git commands and suggests jj equivalents.
Prevents accidental git usage in jj repositories.
"""

import json
import sys
from typing import Optional, Tuple


# Mapping of git commands to jj equivalents
GIT_TO_JJ_MAP = {
    "status": ("jj status", "Show the current working copy status"),
    "st": ("jj status", "Show the current working copy status"),
    "diff": ("jj diff", "Show changes in the working copy"),
    "diff --staged": ("jj diff -r @-", "Show changes in the parent revision"),
    "diff --cached": ("jj diff -r @-", "Show changes in the parent revision"),
    "log": ("jj log", "Show the revision history"),
    "show": ("jj show", "Show a specific revision"),
    "commit": ("jj describe", "Describe the current revision"),
    "commit -m": ("jj describe -m", "Describe the current revision with a message"),
    "add": ("jj squash", "Move changes into a revision (jj doesn't need staging)"),
    "checkout": ("jj new", "Create a new working copy revision"),
    "switch": ("jj new", "Create a new working copy revision"),
    "branch": ("jj bookmark list", "List bookmarks (jj's version of branches)"),
    "branch -a": ("jj bookmark list", "List all bookmarks"),
    "push": ("jj git push", "Push changes to the remote repository"),
    "pull": ("jj git fetch", "Fetch changes from the remote repository"),
    "fetch": ("jj git fetch", "Fetch changes from the remote repository"),
    "merge": ("jj rebase", "Rebase changes (jj uses rebase instead of merge)"),
    "rebase": ("jj rebase", "Rebase revisions onto another revision"),
    "reset": ("jj restore", "Restore files to a previous state"),
    "reset --hard": ("jj abandon", "Abandon current changes"),
    "stash": ("jj new", "Create a new revision (no stash needed in jj)"),
    "cherry-pick": ("jj rebase", "Rebase specific revisions"),
}

# Commands that are safe to run (read-only)
READ_ONLY_GIT_COMMANDS = {
    "status",
    "st",
    "log",
    "show",
    "diff",
    "blame",
    "branch",
    "remote",
    "config --get",
    "rev-parse",
    "describe",
}


def is_read_only_command(git_command: str) -> bool:
    """Check if a git command is read-only."""
    # Strip leading "git " if present
    cmd = git_command.strip()
    if cmd.startswith("git "):
        cmd = cmd[4:]

    # Check if it's a read-only command
    for read_only_cmd in READ_ONLY_GIT_COMMANDS:
        if cmd.startswith(read_only_cmd):
            return True

    return False


def get_jj_equivalent(git_command: str) -> Optional[Tuple[str, str]]:
    """Get the jj equivalent for a git command."""
    # Strip leading "git " if present
    cmd = git_command.strip()
    if cmd.startswith("git "):
        cmd = cmd[4:]

    # Try exact match first
    if cmd in GIT_TO_JJ_MAP:
        return GIT_TO_JJ_MAP[cmd]

    # Try prefix match
    for git_cmd, (jj_cmd, description) in GIT_TO_JJ_MAP.items():
        if cmd.startswith(git_cmd):
            return (jj_cmd, description)

    # No mapping found
    return None


def main():
    """Main hook entry point."""
    try:
        # Read the event data from stdin
        event_data = json.loads(sys.stdin.read())

        # Extract tool information
        tool = event_data.get("tool", {})
        tool_name = tool.get("name", "")

        # Only intercept Bash tools with git commands
        if tool_name != "Bash":
            print(json.dumps({"continue": True}))
            sys.exit(0)

        # Get the command
        params = tool.get("params", {})
        command = params.get("command", "")

        # Check if it's a git command
        if not command.strip().startswith("git "):
            print(json.dumps({"continue": True}))
            sys.exit(0)

        # Allow read-only git commands
        if is_read_only_command(command):
            print(json.dumps({"continue": True}))
            sys.exit(0)

        # Block the git command and suggest jj equivalent
        jj_equivalent = get_jj_equivalent(command)

        if jj_equivalent:
            jj_cmd, description = jj_equivalent
            message = f"""🚫 **Git command blocked in jj repository**

The git command `{command}` was blocked because this is a jj repository.

**Suggested jj equivalent:**
```bash
{jj_cmd}
```

**What it does:** {description}

**Why?** Jujutsu (jj) is a Git-compatible VCS with a different workflow. Using git commands directly can cause confusion. Use jj commands instead!

**Need to run git anyway?** This repository is git-compatible, but prefer jj commands for consistency. See the [official git comparison table](https://jj-vcs.github.io/jj/latest/git-command-table/) for more mappings."""
        else:
            message = f"""🚫 **Git command blocked in jj repository**

The git command `{command}` was blocked because this is a jj repository.

**Why?** This repository uses Jujutsu (jj) for version control. While jj is git-compatible, mixing git and jj commands can cause confusion.

**What to do:**
- Use `/jj:commit` for creating commits
- Use `jj status` for checking the working copy status
- Use `jj log` for viewing history
- See the [official git comparison table](https://jj-vcs.github.io/jj/latest/git-command-table/) for command mappings

**Need help?** Ask me "What's the jj equivalent of `{command}`?" """

        # Block the command
        response = {"continue": False, "system_message": message}

        print(json.dumps(response))
        sys.exit(0)

    except Exception as e:
        # On any error, allow execution to continue (fail open)
        print(
            json.dumps(
                {
                    "continue": True,
                    "system_message": f"Git-to-jj translator hook error: {str(e)}",
                }
            )
        )
        sys.exit(0)


if __name__ == "__main__":
    main()
