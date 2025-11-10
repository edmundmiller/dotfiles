#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["typer", "pytest"]
# ///
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
from typing import Optional, Dict

import typer

# Add hooks directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import _jj_utils

app = typer.Typer()


# ============================================================================
# BUSINESS LOGIC (Testable without CLI)
# ============================================================================


def process_stop_event(event: Dict) -> Dict:
    """
    Process stop event and return hook response dict.

    This function contains all business logic and is testable independently
    of the CLI interface.

    Args:
        event: Parsed event dict

    Returns:
        Dict with 'decision', 'reason', 'continue', and optional 'systemMessage'
    """
    _jj_utils.log_debug("Stop hook: Checking for uncommitted work to commit")

    # Check for uncommitted changes
    status = _jj_utils.get_jj_status()
    if not status["has_changes"]:
        _jj_utils.log_debug("No uncommitted changes - nothing to commit")
        return {
            "decision": "approve",
            "reason": "No uncommitted changes",
            "continue": True,
        }

    # Get current commit info
    current_desc = _jj_utils.get_current_commit_description()
    file_count = status["file_count"]
    is_empty = _jj_utils.is_current_commit_empty()

    _jj_utils.log_debug(f"Found {file_count} uncommitted files")
    _jj_utils.log_debug(f"Current description: {current_desc!r}")
    _jj_utils.log_debug(f"Commit is empty: {is_empty}")

    # Decide if we should auto-commit
    should_commit, commit_reason = _jj_utils.should_auto_commit(status, current_desc)

    if not should_commit:
        # Advisory: Too many files, suggest splitting
        _jj_utils.log_debug(f"Advisory: {commit_reason}")
        system_msg = (
            f"⚠️  You have {file_count} uncommitted files. {commit_reason}\n"
            f"Consider using `/jj:split` to organize changes into focused commits, "
            f"or `/jj:commit` to commit as-is."
        )
        return {
            "decision": "approve",
            "reason": f"Advisory: {commit_reason}",
            "continue": True,
            "systemMessage": system_msg,
        }

    # Auto-commit scenario
    _jj_utils.log_debug(f"Auto-committing: {commit_reason}")

    # Generate commit message with jj-ai-desc
    success, message = _jj_utils.call_jj_ai_desc("@")

    if not success:
        _jj_utils.log_debug(f"jj-ai-desc failed: {message}")
        # Don't block, but inform user
        system_msg = (
            f"⚠️  Attempted to auto-commit {file_count} files but jj-ai-desc failed: {message}\n"
            f"Your changes are still in the working copy. Use `/jj:commit` to commit manually."
        )
        return {
            "decision": "approve",
            "reason": "Advisory: Auto-commit failed",
            "continue": True,
            "systemMessage": system_msg,
        }

    # Commit successful (jj-ai-desc calls jj describe internally)
    _jj_utils.log_debug(f"Generated commit message: {message[:50]}...")

    # Create new empty commit for next work
    returncode, stdout, stderr = _jj_utils.run_jj_command(["new"], check=False)
    if returncode != 0:
        _jj_utils.log_debug(f"jj new failed: {stderr}")
        # Commit worked, but new commit failed - inform user
        system_msg = (
            f"✅ Auto-committed your work ({file_count} files):\n"
            f"   {message[:80]}{'...' if len(message) > 80 else ''}\n\n"
            f"⚠️  Failed to create new commit. Run `jj new` manually before next task."
        )
    else:
        _jj_utils.log_debug("Created new empty commit with jj new")
        # Success - work committed and ready for next task
        system_msg = (
            f"✅ Auto-committed your work ({file_count} files) and created new commit:\n"
            f"   {message[:80]}{'...' if len(message) > 80 else ''}"
        )

    # Special note for moderate file counts
    if file_count >= 4:
        system_msg += f"\n\n💡 Note: {file_count} files were committed. Consider reviewing with `jj log` and splitting if needed."

    return {
        "decision": "approve",
        "reason": f"Auto-committed completed work: {commit_reason}",
        "continue": True,
        "systemMessage": system_msg,
    }


# ============================================================================
# CLI INTERFACE (Thin wrapper for Typer)
# ============================================================================


@app.command()
def main(
    event_json: Optional[str] = typer.Argument(
        None, help="Event JSON (if not provided, reads from stdin)"
    ),
):
    """
    Stop Hook: Auto-commit completed work when Claude finishes responding.

    Reads event JSON from argument or stdin, processes it, and outputs
    hook response JSON to stdout.
    """
    try:
        # Read event JSON from argument or stdin
        if event_json is None:
            event_json = sys.stdin.read()

        # Parse event JSON
        try:
            event = json.loads(event_json)
        except json.JSONDecodeError as e:
            _jj_utils.log_debug(f"Failed to parse event JSON: {e}")
            response = {
                "decision": "approve",
                "reason": "Failed to parse event JSON",
                "continue": True,
            }
            print(json.dumps(response, indent=2))
            return

        # Process event through business logic
        response = process_stop_event(event)

        # Output response
        print(json.dumps(response, indent=2))

    except Exception as e:
        _jj_utils.log_debug(f"Unexpected error: {e}")
        response = {
            "decision": "approve",
            "reason": f"Hook error (approving): {str(e)}",
            "continue": True,
        }
        print(json.dumps(response, indent=2))


# ============================================================================
# AI-SEARCH: TESTS
# ============================================================================

from typer.testing import CliRunner
from unittest.mock import patch

runner = CliRunner()


class TestStopAutoCommitIntegration:
    """REAL integration tests using CliRunner - tests full execution path."""

    def test_no_uncommitted_changes_via_cli(self):
        """INTEGRATION: Full CLI execution with no changes."""

        with patch("_jj_utils.get_jj_status") as mock_status:
            # Setup: no changes
            mock_status.return_value = {"has_changes": False, "file_count": 0}

            # Invoke CLI
            event = {}
            result = runner.invoke(app, [json.dumps(event)])

            # Verify
            assert result.exit_code == 0
            response = json.loads(result.stdout)
            assert response["decision"] == "approve"
            assert "No uncommitted changes" in response["reason"]

    def test_focused_changes_auto_commits(self):
        """INTEGRATION: Focused changes (≤3 files) should auto-commit."""

        with (
            patch("_jj_utils.get_jj_status") as mock_status,
            patch("_jj_utils.get_current_commit_description") as mock_desc,
            patch("_jj_utils.is_current_commit_empty") as mock_empty,
            patch("_jj_utils.should_auto_commit") as mock_should,
            patch("_jj_utils.call_jj_ai_desc") as mock_ai,
            patch("_jj_utils.run_jj_command") as mock_jj,
        ):
            # Setup mocks
            mock_status.return_value = {"has_changes": True, "file_count": 2}
            mock_desc.return_value = "feat: something"
            mock_empty.return_value = False
            mock_should.return_value = (True, "Focused changes")
            mock_ai.return_value = (True, "feat: add feature")
            mock_jj.return_value = (0, "", "")

            # Invoke
            event = {}
            result = runner.invoke(app, [json.dumps(event)])

            # Verify exit and response
            assert result.exit_code == 0
            response = json.loads(result.stdout)
            assert response["decision"] == "approve"
            assert "Auto-committed" in response["systemMessage"]

            # Verify function calls
            mock_ai.assert_called_once_with("@")
            mock_jj.assert_called_once_with(["new"], check=False)

    def test_many_changes_advisory(self):
        """INTEGRATION: Many changes (>7 files) should give advisory."""

        with (
            patch("_jj_utils.get_jj_status") as mock_status,
            patch("_jj_utils.get_current_commit_description") as mock_desc,
            patch("_jj_utils.is_current_commit_empty") as mock_empty,
            patch("_jj_utils.should_auto_commit") as mock_should,
        ):
            mock_status.return_value = {"has_changes": True, "file_count": 10}
            mock_desc.return_value = "feat: something"
            mock_empty.return_value = False
            mock_should.return_value = (False, "Too many files, consider splitting")

            event = {}
            result = runner.invoke(app, [json.dumps(event)])

            assert result.exit_code == 0
            response = json.loads(result.stdout)
            assert response["decision"] == "approve"
            assert "systemMessage" in response
            assert "/jj:split" in response["systemMessage"]

    def test_moderate_changes_with_note(self):
        """INTEGRATION: Moderate changes (4-7 files) should auto-commit with note."""

        with (
            patch("_jj_utils.get_jj_status") as mock_status,
            patch("_jj_utils.get_current_commit_description") as mock_desc,
            patch("_jj_utils.is_current_commit_empty") as mock_empty,
            patch("_jj_utils.should_auto_commit") as mock_should,
            patch("_jj_utils.call_jj_ai_desc") as mock_ai,
            patch("_jj_utils.run_jj_command") as mock_jj,
        ):
            mock_status.return_value = {"has_changes": True, "file_count": 5}
            mock_desc.return_value = "feat: something"
            mock_empty.return_value = False
            mock_should.return_value = (True, "Moderate changes")
            mock_ai.return_value = (True, "feat: add feature")
            mock_jj.return_value = (0, "", "")

            event = {}
            result = runner.invoke(app, [json.dumps(event)])

            assert result.exit_code == 0
            response = json.loads(result.stdout)
            assert response["decision"] == "approve"
            assert "Auto-committed" in response["systemMessage"]
            # Should have note about file count
            assert "5 files were committed" in response["systemMessage"]

    def test_jj_ai_desc_failure_handling(self):
        """INTEGRATION: jj-ai-desc failure should provide advisory."""

        with (
            patch("_jj_utils.get_jj_status") as mock_status,
            patch("_jj_utils.get_current_commit_description") as mock_desc,
            patch("_jj_utils.is_current_commit_empty") as mock_empty,
            patch("_jj_utils.should_auto_commit") as mock_should,
            patch("_jj_utils.call_jj_ai_desc") as mock_ai,
        ):
            mock_status.return_value = {"has_changes": True, "file_count": 2}
            mock_desc.return_value = "some desc"
            mock_empty.return_value = False
            mock_should.return_value = (True, "Focused changes")
            mock_ai.return_value = (False, "jj-ai-desc not found")

            event = {}
            result = runner.invoke(app, [json.dumps(event)])

            assert result.exit_code == 0
            response = json.loads(result.stdout)
            assert response["decision"] == "approve"
            assert "Advisory" in response["reason"]
            assert "jj-ai-desc failed" in response["systemMessage"]

    def test_jj_new_failure_notification(self):
        """INTEGRATION: jj new failure should notify user."""

        with (
            patch("_jj_utils.get_jj_status") as mock_status,
            patch("_jj_utils.get_current_commit_description") as mock_desc,
            patch("_jj_utils.is_current_commit_empty") as mock_empty,
            patch("_jj_utils.should_auto_commit") as mock_should,
            patch("_jj_utils.call_jj_ai_desc") as mock_ai,
            patch("_jj_utils.run_jj_command") as mock_jj,
        ):
            mock_status.return_value = {"has_changes": True, "file_count": 2}
            mock_desc.return_value = "desc"
            mock_empty.return_value = False
            mock_should.return_value = (True, "Focused changes")
            mock_ai.return_value = (True, "feat: add feature")
            mock_jj.return_value = (1, "", "jj new failed")  # Failure!

            event = {}
            result = runner.invoke(app, [json.dumps(event)])

            assert result.exit_code == 0
            response = json.loads(result.stdout)
            assert "Auto-committed" in response["systemMessage"]
            assert "Failed to create new commit" in response["systemMessage"]

    def test_stdin_input(self):
        """INTEGRATION: Reading event from stdin."""

        with patch("_jj_utils.get_jj_status") as mock_status:
            mock_status.return_value = {"has_changes": False, "file_count": 0}

            event = {}
            # Use input parameter to simulate stdin
            result = runner.invoke(app, input=json.dumps(event))

            assert result.exit_code == 0
            response = json.loads(result.stdout)
            assert response["decision"] == "approve"

    def test_malformed_json_approves(self):
        """INTEGRATION: Malformed JSON should approve gracefully."""

        result = runner.invoke(app, ["{invalid json"])

        assert result.exit_code == 0
        response = json.loads(result.stdout)
        assert response["decision"] == "approve"
        assert "Failed to parse" in response["reason"]


if __name__ == "__main__":
    app()
