#!/usr/bin/env -S uv run --script
# /// script
# dependencies = []
# [tool.uv]
# exclude-newer = "2025-08-23T00:00:00Z"
# ///
"""
Todo-to-Commit Hook

PostToolUse hook that intercepts TodoWrite calls and translates them into jj commits.
Each todo becomes a commit in a stack, creating a visual, version-controlled todo list.

Mapping:
- [TODO] prefix = pending task (empty commit)
- [WIP] prefix = in_progress task (current @ working commit)
- No prefix = completed task (regular commit with changes)

The jj commit graph becomes your todo list visualization.
"""

import json
import re
import subprocess
import sys
from typing import List, Dict, Optional


def run_jj_command(args: List[str], check: bool = False) -> tuple[str, int]:
    """Run a jj command and return (output, returncode)."""
    try:
        result = subprocess.run(
            ["jj"] + args,
            capture_output=True,
            text=True,
            check=check
        )
        return result.stdout.strip(), result.returncode
    except subprocess.CalledProcessError as e:
        return e.stderr.strip(), e.returncode
    except Exception as e:
        return f"Error: {e}", 1


def get_todo_commits() -> List[Dict[str, str]]:
    """Get all commits with TODO/WIP prefixes in current stack."""
    # Get commits in stack (ancestors of @, excluding root)
    output, code = run_jj_command([
        "log",
        "-r", "::@",
        "--no-graph",
        "-T", 'change_id ++ "\t" ++ description'
    ])

    if code != 0:
        return []

    todos = []
    for line in output.split("\n"):
        if not line.strip():
            continue

        parts = line.split("\t", 1)
        if len(parts) != 2:
            continue

        change_id, desc = parts

        # Check if this is a todo commit
        if desc.startswith("[TODO]") or desc.startswith("[WIP]"):
            status = "pending" if desc.startswith("[TODO]") else "in_progress"

            # Extract actual content (remove prefix)
            content = re.sub(r'^\[(TODO|WIP)\]\s*', '', desc)

            todos.append({
                "change_id": change_id,
                "description": desc,
                "content": content,
                "status": status
            })

    return todos


def sync_todos_to_commits(todos: List[Dict[str, str]]) -> tuple[bool, str]:
    """
    Synchronize TodoWrite state to jj commits.

    Strategy:
    1. Find existing todo commits in stack
    2. Update descriptions to match new todo states
    3. Create new commits for new todos
    4. Remove commits for deleted todos (mark as [DONE])
    """
    existing_todos = get_todo_commits()

    # Build mapping of existing todos by content
    existing_by_content = {t["content"]: t for t in existing_todos}

    messages = []

    # Process each todo from TodoWrite
    for i, todo in enumerate(todos):
        content = todo["content"]
        status = todo["status"]

        # Determine description based on status
        if status == "pending":
            new_desc = f"[TODO] {content}"
        elif status == "in_progress":
            new_desc = f"[WIP] {content}"
        else:  # completed - no prefix, just the content
            new_desc = content

        # Check if this todo already exists as a commit
        if content in existing_by_content:
            existing = existing_by_content[content]

            # Update if status changed
            if existing["description"] != new_desc:
                change_id = existing["change_id"]
                _, code = run_jj_command([
                    "describe",
                    "-r", change_id,
                    "-m", new_desc
                ])

                if code == 0:
                    messages.append(f"Updated: {new_desc}")
        else:
            # Create new todo commit
            # Insert it at the bottom of the stack (before current @)
            _, code = run_jj_command([
                "new",
                "-A", "@",  # Insert before @
                "-m", new_desc
            ])

            if code == 0:
                messages.append(f"Created: {new_desc}")

    # Find todos that were removed (in commits but not in new list)
    new_contents = {t["content"] for t in todos}
    for existing in existing_todos:
        if existing["content"] not in new_contents:
            # Mark as completed by removing prefix
            if existing["status"] != "completed":
                change_id = existing["change_id"]
                new_desc = existing["content"]  # No prefix = completed
                run_jj_command([
                    "describe",
                    "-r", change_id,
                    "-m", new_desc
                ])
                messages.append(f"Completed: {new_desc}")

    if messages:
        summary = "\n".join(f"  • {m}" for m in messages)
        return True, f"📋 **Todo commits updated:**\n{summary}\n\nView with: `jj log -r '::@'`"

    return True, ""


def main():
    """Main hook entry point."""
    try:
        # Read the event data from stdin
        event_data = json.loads(sys.stdin.read())

        # Check if this is a TodoWrite tool call
        tool_name = event_data.get("tool_name", "")

        if tool_name != "TodoWrite":
            # Not a TodoWrite call, pass through
            print(json.dumps({"continue": True}))
            sys.exit(0)

        # Extract the todos from tool input
        tool_input = event_data.get("tool_input", {})
        todos = tool_input.get("todos", [])

        if not todos:
            # No todos, pass through
            print(json.dumps({"continue": True}))
            sys.exit(0)

        # Sync todos to commits
        success, message = sync_todos_to_commits(todos)

        if success and message:
            response = {
                "continue": True,
                "additionalContext": message
            }
        else:
            response = {"continue": True}

        print(json.dumps(response))
        sys.exit(0)

    except Exception as e:
        # Fail open - allow execution to continue
        print(json.dumps({
            "continue": True,
            "additionalContext": f"⚠️ Todo-to-commit hook error: {str(e)}"
        }))
        sys.exit(0)


if __name__ == "__main__":
    main()
