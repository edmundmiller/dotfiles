#!/usr/bin/env -S uv run --script
# /// script
# dependencies = []
# [tool.uv]
# exclude-newer = "2025-08-23T00:00:00Z"
# ///
"""
JJ Integration Helper

Runs at session end to suggest committing work and preparing for next session.
"""

import subprocess
import sys


def run_jj_command(args):
    """Run a jj command and return output."""
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


def check_current_state():
    """Check if @ has changes and/or description."""
    # Check if @ has description
    desc_output, _ = run_jj_command([
        "log", "-r", "@", "--no-graph",
        "-T", "if(description, 'has', 'none')"
    ])
    has_description = desc_output.strip() == "has"

    # Check if @ is empty
    empty_output, _ = run_jj_command([
        "log", "-r", "@", "--no-graph",
        "-T", "if(empty, 'empty', 'has_changes')"
    ])
    is_empty = empty_output.strip() == "empty"

    # Check if there are any changes in working copy
    status_output, _ = run_jj_command(["status"])
    has_working_changes = "Working copy changes:" in status_output and \
                          any(line.strip().startswith(('M ', 'A ', 'D '))
                              for line in status_output.split('\n'))

    # Count number of changed files (for significance check)
    changed_files = len([line for line in status_output.split('\n')
                        if line.strip().startswith(('M ', 'A ', 'D '))])

    return has_description, is_empty, has_working_changes, changed_files


def validate_plan_vs_actual():
    """
    Validate if the commit description (plan) matches actual work done.

    Returns:
        (needs_update, suggestion_message)
    """
    # Get current description
    desc_output, _ = run_jj_command([
        "log", "-r", "@", "--no-graph", "-T", "description"
    ])
    description = desc_output.strip()

    # Check if description starts with "plan:"
    is_plan = description.lower().startswith("plan:")

    if is_plan:
        # Get what files actually changed
        status_output, _ = run_jj_command(["status"])

        if "Working copy changes:" in status_output:
            # Work was done, plan should be updated to reflect reality
            return True, (
                "📋 **Plan validation:** Work completed!\n\n"
                "The current commit has a 'plan:' description but contains actual work.\n"
                "Consider using `/jj:commit` to describe what was actually accomplished."
            )

    return False, None


def main():
    """Main integration helper logic."""
    has_description, is_empty, has_working_changes, changed_files = check_current_state()

    # Only suggest commits if there's substantial work (3+ files changed)
    # This avoids nagging after simple questions or clarifications
    SIGNIFICANT_CHANGE_THRESHOLD = 3

    # Build suggestion message
    messages = []

    # First, check if plan needs validation
    needs_validation, validation_msg = validate_plan_vs_actual()
    if needs_validation:
        messages.append(validation_msg)
    elif has_working_changes and not has_description and changed_files >= SIGNIFICANT_CHANGE_THRESHOLD:
        messages.append("💡 **Substantial uncommitted work detected!**")
        messages.append("")
        messages.append(f"You have {changed_files} changed files that haven't been described yet.")
        messages.append("")
        messages.append("**Suggested next steps:**")
        messages.append("1. Use `/jj:commit` to describe your work")
        messages.append("2. Or use `/jj:commit \"your message\"` with explicit message")
        messages.append("")
        messages.append("This ensures your work is properly tracked before the next session.")

    # Print suggestions if any (most cases will be silent)
    if messages:
        print("\n" + "\n".join(messages) + "\n")

    sys.exit(0)


if __name__ == "__main__":
    main()
