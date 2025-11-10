#!/usr/bin/env python3
"""
Stop Hook: Auto-commit completed work when Claude finishes responding.

This hook runs after Claude completes its response and decides whether to
automatically commit the work that was just done. It helps maintain clean
commit boundaries and prevents work from accumulating across sessions.

Decision Logic:
1. No uncommitted changes → Approve (nothing to commit)
2. Empty commit + no description → Auto-commit with AI message
3. Focused changes (≤3 files) → Auto-commit with AI message
4. Moderate changes (4-7 files) → Auto-commit with warning
5. Many changes (>7 files) → Advisory to split

After auto-commit, runs `jj new` to create empty commit for next work.

Returns JSON with decision, reason, and systemMessage for user visibility.
"""

import json
import sys
import os

# Add hooks directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _jj_utils import (
    get_jj_status,
    get_current_commit_description,
    should_auto_commit,
    call_jj_ai_desc,
    run_jj_command,
    create_hook_response,
    is_current_commit_empty,
    log_debug,
)


def main():
    """Main hook entry point."""
    # Parse event JSON from stdin or args
    event_json = sys.argv[1] if len(sys.argv) > 1 else sys.stdin.read()

    try:
        event = json.loads(event_json)
    except json.JSONDecodeError as e:
        log_debug(f"Failed to parse event JSON: {e}")
        print(create_hook_response("approve", "Failed to parse event JSON"))
        sys.exit(0)

    log_debug("Stop hook: Checking for uncommitted work to commit")

    # Check for uncommitted changes
    status = get_jj_status()
    if not status["has_changes"]:
        log_debug("No uncommitted changes - nothing to commit")
        print(create_hook_response("approve", "No uncommitted changes"))
        sys.exit(0)

    # Get current commit info
    current_desc = get_current_commit_description()
    file_count = status["file_count"]
    is_empty = is_current_commit_empty()

    log_debug(f"Found {file_count} uncommitted files")
    log_debug(f"Current description: {current_desc!r}")
    log_debug(f"Commit is empty: {is_empty}")

    # Decide if we should auto-commit
    should_commit, commit_reason = should_auto_commit(status, current_desc)

    if not should_commit:
        # Advisory: Too many files, suggest splitting
        log_debug(f"Advisory: {commit_reason}")
        system_msg = (
            f"⚠️  You have {file_count} uncommitted files. {commit_reason}\n"
            f"Consider using `/jj:split` to organize changes into focused commits, "
            f"or `/jj:commit` to commit as-is."
        )
        print(
            create_hook_response(
                "approve", f"Advisory: {commit_reason}", system_message=system_msg
            )
        )
        sys.exit(0)

    # Auto-commit scenario
    log_debug(f"Auto-committing: {commit_reason}")

    # Generate commit message with jj-ai-desc
    success, message = call_jj_ai_desc("@")

    if not success:
        log_debug(f"jj-ai-desc failed: {message}")
        # Don't block, but inform user
        system_msg = (
            f"⚠️  Attempted to auto-commit {file_count} files but jj-ai-desc failed: {message}\n"
            f"Your changes are still in the working copy. Use `/jj:commit` to commit manually."
        )
        print(
            create_hook_response(
                "approve", "Advisory: Auto-commit failed", system_message=system_msg
            )
        )
        sys.exit(0)

    # Commit successful (jj-ai-desc calls jj describe internally)
    log_debug(f"Generated commit message: {message[:50]}...")

    # Create new empty commit for next work
    returncode, stdout, stderr = run_jj_command(["new"], check=False)
    if returncode != 0:
        log_debug(f"jj new failed: {stderr}")
        # Commit worked, but new commit failed - inform user
        system_msg = (
            f"✅ Auto-committed your work ({file_count} files):\n"
            f"   {message[:80]}{'...' if len(message) > 80 else ''}\n\n"
            f"⚠️  Failed to create new commit. Run `jj new` manually before next task."
        )
    else:
        log_debug("Created new empty commit with jj new")
        # Success - work committed and ready for next task
        system_msg = (
            f"✅ Auto-committed your work ({file_count} files) and created new commit:\n"
            f"   {message[:80]}{'...' if len(message) > 80 else ''}"
        )

    # Special note for moderate file counts
    if file_count >= 4:
        system_msg += f"\n\n💡 Note: {file_count} files were committed. Consider reviewing with `jj log` and splitting if needed."

    # Approve and inform user
    print(
        create_hook_response(
            "approve",
            f"Auto-committed completed work: {commit_reason}",
            system_message=system_msg,
        )
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log_debug(f"Unexpected error: {e}")
        # Always approve on errors to avoid blocking
        print(create_hook_response("approve", f"Hook error (approving): {str(e)}"))
        sys.exit(0)
