#!/usr/bin/env -S uv run --script
# /// script
# dependencies = []
# [tool.uv]
# exclude-newer = "2025-08-23T00:00:00Z"
# ///
"""
Todo Commit Hook

Creates JJ changes for each todo item and automatically switches between them
as the agent works through the list. This enables a clean, granular commit
history that maps directly to the task breakdown.

Flow:
1. TodoWrite is called with a list of todos
2. Hook creates a JJ change for each todo item
3. As todos transition to in_progress, hook automatically runs `jj edit` to that change
4. When completed, changes remain for eventual squashing/cleanup
"""

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import List, Dict, Optional, Tuple


# State file location
STATE_FILE = Path.home() / ".config" / "claude" / "jj-todo-state.json"


def run_jj_command(args: List[str]) -> Tuple[str, int]:
    """Run a jj command and return (output, returncode)."""
    try:
        result = subprocess.run(
            ["jj"] + args,
            capture_output=True,
            text=True,
            check=False,
            cwd=os.getcwd()
        )
        return result.stdout.strip(), result.returncode
    except Exception as e:
        return f"Error: {e}", 1


def get_current_change_id() -> Optional[str]:
    """Get the current change ID (@)."""
    output, code = run_jj_command([
        "log", "-r", "@", "--no-graph", "-T", "change_id"
    ])
    if code == 0:
        return output.strip()
    return None


def load_state() -> Dict:
    """Load the todo-to-change mapping state."""
    if STATE_FILE.exists():
        try:
            with open(STATE_FILE, 'r') as f:
                return json.load(f)
        except Exception:
            pass

    return {
        "base_change_id": get_current_change_id(),
        "todos": [],
        "session_active": False
    }


def save_state(state: Dict):
    """Save the todo-to-change mapping state."""
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(STATE_FILE, 'w') as f:
        json.dump(state, f, indent=2)


def create_jj_change(todo_content: str) -> Optional[str]:
    """
    Create a new JJ change for a todo item.
    Returns the change_id of the created change, or None on failure.
    """
    # Create new change with todo description
    description = f"todo: {todo_content}"
    _, code = run_jj_command(["new", "-m", description])

    if code != 0:
        return None

    # Get the change_id we just created
    change_id = get_current_change_id()
    return change_id


def find_todo_by_content(todos: List[Dict], content: str) -> Optional[Dict]:
    """Find a todo by its content."""
    for todo in todos:
        if todo.get("content") == content:
            return todo
    return None


def detect_status_change(old_todos: List[Dict], new_todos: List[Dict]) -> Optional[Dict]:
    """
    Detect if a todo changed to in_progress status.
    Returns the todo that changed, or None.
    """
    for new_todo in new_todos:
        if new_todo.get("status") != "in_progress":
            continue

        old_todo = find_todo_by_content(old_todos, new_todo.get("content", ""))
        if old_todo and old_todo.get("status") != "in_progress":
            # This todo just became in_progress
            return new_todo

    return None


def is_initialization(state: Dict, new_todos: List[Dict]) -> bool:
    """
    Check if this is the initial todo list creation (vs an update).
    Returns True if this appears to be the first time todos are being set up.
    """
    # If we have no previous todos and multiple new ones, it's initialization
    if not state.get("todos") and len(new_todos) > 1:
        return True

    # If session wasn't active, it's initialization
    if not state.get("session_active"):
        return True

    return False


def initialize_todo_changes(state: Dict, todos: List[Dict]) -> Tuple[bool, str]:
    """
    Create JJ changes for all todos in the list.
    Returns (success, message).
    """
    base_change = get_current_change_id()
    state["base_change_id"] = base_change
    state["session_active"] = True

    messages = []
    created_changes = []

    for todo in todos:
        content = todo.get("content", "")
        if not content:
            continue

        change_id = create_jj_change(content)
        if change_id:
            created_changes.append({
                "content": content,
                "activeForm": todo.get("activeForm", content),
                "status": todo.get("status", "pending"),
                "jj_change_id": change_id
            })
            messages.append(f"  ✓ Created change {change_id[:12]} for: {content}")
        else:
            messages.append(f"  ✗ Failed to create change for: {content}")

    if not created_changes:
        return False, "No changes created"

    # Return to base change
    if base_change:
        run_jj_command(["edit", base_change])

    state["todos"] = created_changes
    save_state(state)

    summary = f"""
📋 **Created {len(created_changes)} JJ changes for todos:**

{chr(10).join(messages)}

🔄 Returned to base change {base_change[:12] if base_change else 'unknown'}
💡 As you work through todos, I'll automatically switch to the corresponding JJ change
"""

    return True, summary


def handle_status_change(state: Dict, changed_todo: Dict) -> Tuple[bool, str]:
    """
    Handle a todo status change by switching to the corresponding JJ change.
    Returns (success, message).
    """
    content = changed_todo.get("content", "")

    # Find the corresponding tracked todo
    tracked_todo = find_todo_by_content(state.get("todos", []), content)
    if not tracked_todo:
        return False, f"Could not find tracked change for: {content}"

    change_id = tracked_todo.get("jj_change_id")
    if not change_id:
        return False, f"No change_id found for: {content}"

    # Switch to this change
    output, code = run_jj_command(["edit", change_id])

    if code != 0:
        return False, f"Failed to switch to change {change_id}: {output}"

    # Update the status in our state
    for todo in state.get("todos", []):
        if todo.get("content") == content:
            todo["status"] = "in_progress"
    save_state(state)

    message = f"""
🎯 **Switched to JJ change {change_id[:12]}**
📝 Working on: {content}
"""

    return True, message


def update_todo_statuses(state: Dict, new_todos: List[Dict]):
    """Update the status of tracked todos based on new todo list."""
    for new_todo in new_todos:
        content = new_todo.get("content", "")
        for tracked_todo in state.get("todos", []):
            if tracked_todo.get("content") == content:
                tracked_todo["status"] = new_todo.get("status", "pending")
    save_state(state)


def main():
    """Main hook entry point."""
    try:
        # Read the event data from stdin
        event_data = json.loads(sys.stdin.read())

        # Extract tool information
        tool = event_data.get("tool", {})
        tool_name = tool.get("name", "")

        # Only process TodoWrite calls
        if tool_name != "TodoWrite":
            print(json.dumps({"continue": True}))
            sys.exit(0)

        # Extract todos from tool parameters
        params = tool.get("params", {})
        new_todos = params.get("todos", [])

        if not new_todos:
            print(json.dumps({"continue": True}))
            sys.exit(0)

        # Load current state
        state = load_state()

        # Check if this is initialization or an update
        if is_initialization(state, new_todos):
            # Create JJ changes for all todos
            success, message = initialize_todo_changes(state, new_todos)

            response = {
                "continue": True,
                "system_message": message if success else None
            }
        else:
            # Check for status changes
            old_todos = state.get("todos", [])
            changed_todo = detect_status_change(old_todos, new_todos)

            if changed_todo:
                # Switch to the corresponding JJ change
                success, message = handle_status_change(state, changed_todo)
                response = {
                    "continue": True,
                    "system_message": message if success else None
                }
            else:
                # Just update statuses without switching
                update_todo_statuses(state, new_todos)
                response = {"continue": True}

        print(json.dumps(response))
        sys.exit(0)

    except Exception as e:
        # On any error, allow execution to continue (fail open)
        print(json.dumps({
            "continue": True,
            "system_message": f"⚠️ Todo commit hook error: {str(e)}"
        }))
        sys.exit(0)


if __name__ == "__main__":
    main()
