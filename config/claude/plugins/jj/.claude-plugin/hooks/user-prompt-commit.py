#!/usr/bin/env python3
"""
UserPromptSubmit Hook: Intelligent commit boundary detection.

This hook runs before Claude processes user input and decides whether to
commit previous work before starting new tasks. It prevents commits from
getting cluttered by detecting scope shifts and managing commit boundaries.

Decision Logic:
1. No uncommitted changes → Approve (nothing to commit)
2. Uncommitted changes + no scope shift → Approve (continuation of current work)
3. Uncommitted changes + scope shift → Auto-commit with AI message, then jj new
4. Ambiguous cases → Advisory with systemMessage

Returns JSON with decision, reason, and optional systemMessage for Claude.
"""

import json
import sys
import os

# Add hooks directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _jj_utils import (
    get_jj_status,
    get_current_commit_description,
    detect_scope_shift,
    call_jj_ai_desc,
    run_jj_command,
    create_hook_response,
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
        # Fallback: approve if we can't parse
        print(
            create_hook_response(
                "approve", "Failed to parse event JSON", continue_flag=True
            )
        )
        sys.exit(0)

    # Extract user prompt
    user_prompt = event.get("prompt", "")
    if not user_prompt:
        log_debug("No user prompt in event")
        print(create_hook_response("approve", "No user prompt to analyze"))
        sys.exit(0)

    log_debug(f"Analyzing prompt: {user_prompt[:100]}...")

    # Check for uncommitted changes
    status = get_jj_status()
    if not status["has_changes"]:
        log_debug("No uncommitted changes - approving")
        print(create_hook_response("approve", "No uncommitted changes to commit"))
        sys.exit(0)

    # Get current commit info
    current_desc = get_current_commit_description()
    file_count = status["file_count"]

    log_debug(
        f"Found {file_count} uncommitted files, current description: {current_desc!r}"
    )

    # Detect scope shift
    is_scope_shift, shift_reason = detect_scope_shift(user_prompt)

    if not is_scope_shift:
        # No scope shift → continue working on current commit
        log_debug(f"No scope shift detected: {shift_reason}")
        print(
            create_hook_response(
                "approve",
                f"Continuing current work: {shift_reason}",
                system_message=None,
            )
        )
        sys.exit(0)

    # Scope shift detected with uncommitted changes
    log_debug(f"Scope shift detected: {shift_reason}")

    # Decision: Auto-commit or Advisory?
    if current_desc is None and file_count > 5:
        # Many uncommitted files without description → suggest manual commit
        log_debug("Advisory: Too many files without description")
        system_msg = (
            f"⚠️  Detected scope shift in user request, but you have {file_count} uncommitted "
            f"files without a commit description. Consider using `/jj:commit` or `/jj:split` "
            f"before starting new work to avoid cluttered commits."
        )
        print(
            create_hook_response(
                "approve",
                "Advisory: Suggest manual commit for large changeset",
                system_message=system_msg,
            )
        )
        sys.exit(0)

    # Auto-commit scenario: scope shift + reasonable changeset
    log_debug(f"Auto-committing {file_count} files before new work")

    # Generate commit message with jj-ai-desc
    success, message = call_jj_ai_desc("@")

    if not success:
        log_debug(f"jj-ai-desc failed: {message}")
        # Fallback: use basic description
        system_msg = (
            f"⚠️  Detected scope shift. Attempted to auto-commit {file_count} files but "
            f"jj-ai-desc failed: {message}. Consider committing manually before proceeding."
        )
        print(
            create_hook_response(
                "approve",
                "Advisory: Auto-commit failed, suggesting manual commit",
                system_message=system_msg,
            )
        )
        sys.exit(0)

    # Commit was successful (jj-ai-desc calls jj describe internally)
    log_debug(f"Generated commit message: {message[:50]}...")

    # Create new empty commit for upcoming work
    returncode, stdout, stderr = run_jj_command(["new"], check=False)
    if returncode != 0:
        log_debug(f"jj new failed: {stderr}")
        # Continue anyway - at least we described the commit
        system_msg = (
            f"✅ Auto-committed previous work: {message[:60]}...\n"
            f"⚠️  Failed to create new commit (jj new). You may want to run it manually."
        )
    else:
        log_debug("Created new empty commit with jj new")
        system_msg = (
            f"✅ Auto-committed previous work ({file_count} files) and created new commit for this task.\n"
            f"Commit: {message[:80]}{'...' if len(message) > 80 else ''}"
        )

    # Approve and inform Claude
    print(
        create_hook_response(
            "approve",
            f"Auto-committed previous work due to scope shift: {shift_reason}",
            system_message=system_msg,
        )
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log_debug(f"Unexpected error: {e}")
        # Always approve on errors to avoid blocking user
        print(create_hook_response("approve", f"Hook error (approving): {str(e)}"))
        sys.exit(0)
