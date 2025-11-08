#!/usr/bin/env -S uv run --script
# /// script
# dependencies = []
# [tool.uv]
# exclude-newer = "2025-08-23T00:00:00Z"
# ///
"""
Plan Commit Hook

Creates a commit describing what Claude is ABOUT to do after receiving user instructions.
This establishes intent before work begins, enabling plan validation at session end.
"""

import json
import re
import subprocess
import sys
from typing import Tuple


def run_jj_command(args):
    """Run a jj command and return output."""
    try:
        result = subprocess.run(
            ["jj"] + args, capture_output=True, text=True, check=False
        )
        return result.stdout.strip(), result.returncode
    except Exception as e:
        return f"Error: {e}", 1


def check_current_state():
    """Check if @ has description and changes."""
    # Check if @ has description
    desc_output, _ = run_jj_command(
        ["log", "-r", "@", "--no-graph", "-T", "if(description, 'has', 'none')"]
    )
    has_description = desc_output.strip() == "has"

    # Check if @ is empty
    empty_output, _ = run_jj_command(
        ["log", "-r", "@", "--no-graph", "-T", "if(empty, 'empty', 'has_changes')"]
    )
    is_empty = empty_output.strip() == "empty"

    return has_description, is_empty


def is_substantial_task(prompt: str) -> bool:
    """
    Determine if the user prompt is a substantial task requiring a plan commit.

    Returns False for:
    - Simple questions
    - Clarifications
    - Information requests

    Returns True for:
    - Implementation requests
    - Refactoring tasks
    - Multi-step work
    """
    prompt_lower = prompt.lower().strip()

    # Question patterns (don't need plan commits)
    question_patterns = [
        r"^(what|why|how|when|where|who|which|can you explain)",
        r"^(is |are |does |do |did |has |have |will |would |could |should )",
        r"\?$",  # Ends with question mark
        r"^(tell me|show me|explain)",
    ]

    for pattern in question_patterns:
        if re.search(pattern, prompt_lower):
            return False

    # Task patterns (need plan commits)
    task_patterns = [
        r"\b(add|create|implement|build|make|write|fix|update|refactor|change|modify)\b",
        r"\b(remove|delete|clean|optimize|improve|enhance)\b",
        r"\b(install|configure|setup|integrate)\b",
    ]

    for pattern in task_patterns:
        if re.search(pattern, prompt_lower):
            return True

    return False


def create_plan_commit(prompt: str) -> Tuple[bool, str]:
    """
    Create a plan commit describing what's about to happen.

    Returns:
        (success, message)
    """
    # Create plan description
    plan_msg = f"plan: {prompt[:200]}"  # Truncate if too long

    # Use jj describe to set plan
    _, return_code = run_jj_command(["describe", "-m", plan_msg])

    if return_code == 0:
        return True, f"📋 **Plan committed:** {plan_msg}"
    else:
        return False, "Failed to create plan commit"


def main():
    """Main hook entry point."""
    try:
        # Read the event data from stdin
        event_data = json.loads(sys.stdin.read())

        # Extract user prompt
        prompt = event_data.get("prompt", "")

        if not prompt:
            # No prompt, continue normally
            print(json.dumps({"continue": True}))
            sys.exit(0)

        # Check if this is a substantial task
        if not is_substantial_task(prompt):
            # Simple question or clarification, no plan needed
            print(json.dumps({"continue": True}))
            sys.exit(0)

        # Check current state
        has_description, is_empty = check_current_state()

        # Only create plan if @ is empty and has no description
        # (Fresh start for new work)
        if is_empty and not has_description:
            success, message = create_plan_commit(prompt)

            if success:
                response = {"continue": True, "system_message": message}
            else:
                response = {"continue": True}

            print(json.dumps(response))
            sys.exit(0)
        else:
            # Already have work in progress, don't interfere
            print(json.dumps({"continue": True}))
            sys.exit(0)

    except Exception as e:
        # On any error, allow execution to continue (fail open)
        print(
            json.dumps(
                {
                    "continue": True,
                    "system_message": f"Plan commit hook error: {str(e)}",
                }
            )
        )
        sys.exit(0)


if __name__ == "__main__":
    main()
