#!/usr/bin/env python3
"""
Shared utilities for jj commit management hooks.
Provides common functions for jj status parsing, commit analysis, and hook response generation.
"""

import json
import subprocess
import sys
from typing import Dict, List, Optional, Tuple
import re


def run_jj_command(args: List[str], check: bool = True) -> Tuple[int, str, str]:
    """
    Run a jj command and return (returncode, stdout, stderr).

    Args:
        args: Command arguments (e.g., ['status', '--no-pager'])
        check: Whether to raise on non-zero exit code

    Returns:
        Tuple of (returncode, stdout, stderr)
    """
    try:
        result = subprocess.run(
            ["jj"] + args, capture_output=True, text=True, check=check
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.CalledProcessError as e:
        if check:
            raise
        return e.returncode, e.stdout, e.stderr


def get_jj_status() -> Dict[str, any]:
    """
    Get jj status and parse into structured data.

    Returns:
        Dict with keys:
        - has_changes: bool
        - modified_files: List[str]
        - added_files: List[str]
        - removed_files: List[str]
        - file_count: int
        - raw_output: str
    """
    returncode, stdout, stderr = run_jj_command(["status", "--no-pager"])

    # Parse jj status output
    modified = []
    added = []
    removed = []

    for line in stdout.splitlines():
        line = line.strip()
        if line.startswith("M "):
            modified.append(line[2:].strip())
        elif line.startswith("A "):
            added.append(line[2:].strip())
        elif line.startswith("D ") or line.startswith("R "):
            removed.append(line[2:].strip())

    has_changes = bool(modified or added or removed)
    file_count = len(modified) + len(added) + len(removed)

    # Check if it says "No changes" or "The working copy is clean"
    if "No changes" in stdout or "working copy is clean" in stdout.lower():
        has_changes = False

    return {
        "has_changes": has_changes,
        "modified_files": modified,
        "added_files": added,
        "removed_files": removed,
        "file_count": file_count,
        "raw_output": stdout,
    }


def get_current_commit_description() -> Optional[str]:
    """
    Get the description of the current commit (@).

    Returns:
        Commit description or None if empty/no description
    """
    returncode, stdout, stderr = run_jj_command(
        ["log", "--no-pager", "-r", "@", "-T", "description"]
    )
    description = stdout.strip()

    # Empty commits show as just whitespace or "(no description set)"
    if (
        not description
        or description == "(no description set)"
        or description.isspace()
    ):
        return None

    return description


def get_jj_diff(revision: str = "@") -> str:
    """
    Get diff for specified revision.

    Args:
        revision: JJ revision (default: '@')

    Returns:
        Diff output as string
    """
    returncode, stdout, stderr = run_jj_command(["diff", "--no-pager", "-r", revision])
    return stdout


def call_jj_ai_desc(revision: str = "@") -> Tuple[bool, str]:
    """
    Call jj-ai-desc to generate a commit message.

    Args:
        revision: JJ revision to describe (default: '@')

    Returns:
        Tuple of (success: bool, message: str)
    """
    try:
        result = subprocess.run(
            ["jj-ai-desc", "-r", revision], capture_output=True, text=True, timeout=30
        )

        if result.returncode == 0:
            return True, result.stdout.strip()
        else:
            return False, f"jj-ai-desc failed: {result.stderr}"

    except subprocess.TimeoutExpired:
        return False, "jj-ai-desc timed out after 30s"
    except FileNotFoundError:
        return False, "jj-ai-desc not found in PATH"
    except Exception as e:
        return False, f"jj-ai-desc error: {str(e)}"


def has_uncommitted_changes() -> bool:
    """
    Check if there are uncommitted changes in the working copy.

    Returns:
        True if there are uncommitted changes
    """
    status = get_jj_status()
    return status["has_changes"]


def is_current_commit_empty() -> bool:
    """
    Check if the current commit (@) is empty (no changes).

    Returns:
        True if commit is empty
    """
    returncode, stdout, stderr = run_jj_command(
        ["log", "--no-pager", "-r", "@", "-T", "empty"]
    )
    return stdout.strip().lower() == "true"


def detect_scope_shift(user_prompt: str) -> Tuple[bool, str]:
    """
    Detect if user prompt indicates a shift to new work/scope.

    Args:
        user_prompt: The user's prompt text

    Returns:
        Tuple of (is_shift: bool, reason: str)
    """
    # Normalize prompt
    prompt_lower = user_prompt.lower().strip()

    # Strong indicators of scope shift
    strong_indicators = [
        r"\bnow\s+(?:let\'?s|we|do|add|create|implement|fix)",
        r"\bnext\s+(?:task|step|up|let\'?s|we)",
        r"switch\s+to",
        r"move\s+on\s+to",
        r"start\s+(?:working\s+on|implementing|adding|creating)",
        r"new\s+(?:feature|task|work|project|component)",
        r"(?:also|additionally|furthermore)\s+(?:add|create|implement)",
        r"different\s+(?:task|feature|work)",
        r"instead\s+(?:let\'?s|we|do)",
    ]

    for pattern in strong_indicators:
        if re.search(pattern, prompt_lower):
            return True, f"Scope shift detected: matched pattern '{pattern}'"

    # Medium indicators - contextual
    medium_indicators = [
        r"\blet\'?s\s+(?:add|create|implement|build|make)",
        r"can\s+you\s+(?:add|create|implement|build|make|now)",
        r"(?:please|could you)\s+(?:add|create|implement)",
    ]

    # Check for imperative mood at start
    if prompt_lower.startswith(
        ("add ", "create ", "implement ", "build ", "make ", "refactor ", "fix ")
    ):
        return True, "Imperative command suggests new task"

    for pattern in medium_indicators:
        if re.search(pattern, prompt_lower):
            # Medium confidence - might be scope shift
            return True, f"Possible scope shift: matched pattern '{pattern}'"

    # No clear indicators
    return False, "No scope shift indicators detected"


def should_auto_commit(
    status: Dict, current_description: Optional[str]
) -> Tuple[bool, str]:
    """
    Heuristics to determine if changes should be auto-committed.

    Args:
        status: Output from get_jj_status()
        current_description: Current commit description or None

    Returns:
        Tuple of (should_commit: bool, reason: str)
    """
    if not status["has_changes"]:
        return False, "No uncommitted changes"

    file_count = status["file_count"]

    # Empty commit with no description and changes → auto-commit
    if current_description is None:
        if file_count <= 5:
            return (
                True,
                f"Empty commit with {file_count} changed files - suitable for auto-commit",
            )
        else:
            return False, f"Empty commit with {file_count} files - might need splitting"

    # Has description → focused changes
    if file_count <= 3:
        return True, f"Focused changes ({file_count} files) with existing description"

    # More files → might be mixed concerns
    if file_count <= 7:
        return (
            True,
            f"Moderate changes ({file_count} files) - auto-committing but might need review",
        )

    return False, f"Many files changed ({file_count}) - likely needs splitting"


def create_hook_response(
    decision: str,
    reason: str,
    continue_flag: bool = True,
    stop_reason: Optional[str] = None,
    system_message: Optional[str] = None,
) -> str:
    """
    Create a properly formatted hook response JSON.

    Args:
        decision: 'approve' or 'block'
        reason: Explanation for the decision
        continue_flag: Whether Claude should continue
        stop_reason: Message shown to user if blocking
        system_message: Additional context for Claude

    Returns:
        JSON string for hook response
    """
    response = {"decision": decision, "reason": reason, "continue": continue_flag}

    if stop_reason:
        response["stopReason"] = stop_reason

    if system_message:
        response["systemMessage"] = system_message

    return json.dumps(response, indent=2)


def log_debug(message: str):
    """Log debug message to stderr."""
    print(f"[jj-hook-debug] {message}", file=sys.stderr)


def main():
    """Test utilities when run directly."""
    print("Testing jj utilities...")

    print("\n1. JJ Status:")
    status = get_jj_status()
    print(json.dumps(status, indent=2))

    print("\n2. Current Commit Description:")
    desc = get_current_commit_description()
    print(f"Description: {desc!r}")

    print("\n3. Is Empty:")
    print(f"Empty: {is_current_commit_empty()}")

    print("\n4. Has Uncommitted Changes:")
    print(f"Has changes: {has_uncommitted_changes()}")

    print("\n5. Scope Shift Detection:")
    test_prompts = [
        "Now let's add a new feature",
        "Can you fix this bug?",
        "Switch to working on the API",
        "Continue improving this function",
        "Add error handling",
    ]
    for prompt in test_prompts:
        is_shift, reason = detect_scope_shift(prompt)
        print(f"  '{prompt}' → {is_shift} ({reason})")

    print("\n6. Should Auto Commit:")
    should_commit, reason = should_auto_commit(status, desc)
    print(f"Should commit: {should_commit} ({reason})")


if __name__ == "__main__":
    main()
