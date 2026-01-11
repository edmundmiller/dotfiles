#!/usr/bin/env -S uv run --script
# /// script
# dependencies = []
# [tool.uv]
# exclude-newer = "2025-08-23T00:00:00Z"
# ///
"""
Todo Cleanup Helper

Automates cleanup of todo-created JJ changes with different strategies.
Can be called directly or via /todo-squash command.
"""

import json
import subprocess
import sys
from pathlib import Path
from typing import List, Dict, Tuple, Optional


STATE_FILE = Path.home() / ".config" / "claude" / "jj-todo-state.json"


def run_jj_command(args: List[str]) -> Tuple[str, int]:
    """Run a jj command and return (output, returncode)."""
    try:
        result = subprocess.run(
            ["jj"] + args,
            capture_output=True,
            text=True,
            check=False
        )
        return result.stdout.strip(), result.returncode
    except Exception as e:
        return f"Error: {e}", 1


def load_state() -> Optional[Dict]:
    """Load the todo state file."""
    if not STATE_FILE.exists():
        return None

    try:
        with open(STATE_FILE, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading state: {e}", file=sys.stderr)
        return None


def get_todo_changes(state: Dict) -> List[Dict]:
    """Get list of todo changes from state."""
    return state.get("todos", [])


def show_current_stack():
    """Display the current commit stack."""
    print("\n📚 Current commit stack:\n")
    output, code = run_jj_command([
        "log", "-r", "all()", "--limit", "20",
        "-T", 'concat(change_id.short(), " ", if(empty, "∅ ", "● "), description.first_line(), "\\n")'
    ])
    print(output)


def squash_all_strategy(state: Dict) -> bool:
    """
    Strategy A: Squash all todo changes into base.
    Returns True on success.
    """
    base_change = state.get("base_change_id")
    todos = get_todo_changes(state)

    if not base_change:
        print("❌ No base change found in state", file=sys.stderr)
        return False

    print(f"\n🔄 Squashing {len(todos)} todo changes into base {base_change[:12]}...\n")

    # Edit the base change
    _, code = run_jj_command(["edit", base_change])
    if code != 0:
        print(f"❌ Failed to edit base change", file=sys.stderr)
        return False

    # Squash each todo change (from oldest to newest)
    for i, todo in enumerate(reversed(todos)):
        change_id = todo.get("jj_change_id")
        content = todo.get("content", "")

        if not change_id:
            continue

        print(f"  [{i+1}/{len(todos)}] Squashing: {content}")
        _, code = run_jj_command(["squash", "-r", change_id])

        if code != 0:
            print(f"    ⚠️  Warning: Failed to squash {change_id[:12]}")
        else:
            print(f"    ✓ Squashed {change_id[:12]}")

    print("\n✅ All changes squashed!")
    print("\n💡 Next step: Update the description with `jj describe -m \"<summary>\"`")
    return True


def remove_todo_prefixes_strategy(state: Dict) -> bool:
    """
    Strategy C: Remove 'todo:' prefix from descriptions.
    Returns True on success.
    """
    todos = get_todo_changes(state)

    print(f"\n🔄 Cleaning up {len(todos)} todo descriptions...\n")

    for i, todo in enumerate(todos):
        change_id = todo.get("jj_change_id")
        content = todo.get("content", "")

        if not change_id or not content:
            continue

        # Remove "todo: " prefix for cleaner description
        new_desc = content

        print(f"  [{i+1}/{len(todos)}] {change_id[:12]}: {content}")
        _, code = run_jj_command(["describe", "-r", change_id, "-m", new_desc])

        if code != 0:
            print(f"    ⚠️  Warning: Failed to update description")
        else:
            print(f"    ✓ Updated")

    print("\n✅ Descriptions cleaned up!")
    return True


def show_status(state: Dict):
    """Show the status of todo changes."""
    todos = get_todo_changes(state)
    base_change = state.get("base_change_id", "unknown")

    print(f"\n📊 Todo Session Status")
    print(f"{'='*50}")
    print(f"Base change:  {base_change[:12] if base_change != 'unknown' else base_change}")
    print(f"Total todos:  {len(todos)}")
    print(f"Completed:    {sum(1 for t in todos if t.get('status') == 'completed')}")
    print(f"In progress:  {sum(1 for t in todos if t.get('status') == 'in_progress')}")
    print(f"Pending:      {sum(1 for t in todos if t.get('status') == 'pending')}")
    print(f"{'='*50}\n")

    print("📝 Todo changes:")
    for i, todo in enumerate(todos):
        status_icon = {
            'completed': '✅',
            'in_progress': '🔄',
            'pending': '⏳'
        }.get(todo.get('status'), '❓')

        change_id = todo.get('jj_change_id', 'unknown')[:12]
        content = todo.get('content', 'unknown')

        print(f"  {i+1}. {status_icon} {change_id}: {content}")


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Usage: todo-cleanup.py <command>")
        print("\nCommands:")
        print("  status         - Show todo session status")
        print("  show           - Show current commit stack")
        print("  squash-all     - Squash all todos into base (Strategy A)")
        print("  clean-desc     - Remove 'todo:' prefixes (Strategy C)")
        sys.exit(1)

    command = sys.argv[1]

    # Load state
    state = load_state()
    if not state:
        print("❌ No todo state file found. Have you created any todos with the hook enabled?")
        sys.exit(1)

    # Execute command
    if command == "status":
        show_status(state)

    elif command == "show":
        show_current_stack()

    elif command == "squash-all":
        success = squash_all_strategy(state)
        if success:
            show_current_stack()
            print("\n💾 State file preserved at:", STATE_FILE)
            print("   You can remove it with: rm", STATE_FILE)
        sys.exit(0 if success else 1)

    elif command == "clean-desc":
        success = remove_todo_prefixes_strategy(state)
        if success:
            show_current_stack()
        sys.exit(0 if success else 1)

    else:
        print(f"❌ Unknown command: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()
