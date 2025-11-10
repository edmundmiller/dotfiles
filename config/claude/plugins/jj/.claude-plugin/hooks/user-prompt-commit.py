#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["typer", "pytest"]
# ///
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
from typing import Optional, Dict

import typer

# Add hooks directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import _jj_utils

app = typer.Typer()


# ============================================================================
# BUSINESS LOGIC (Testable without CLI)
# ============================================================================


def process_user_prompt_event(event: Dict) -> Dict:
    """
    Process user prompt event and return hook response dict.

    This function contains all business logic and is testable independently
    of the CLI interface.

    Args:
        event: Parsed event dict with 'prompt' key

    Returns:
        Dict with 'decision', 'reason', 'continue', and optional 'systemMessage'
    """
    # Extract user prompt
    user_prompt = event.get("prompt", "")
    if not user_prompt:
        _jj_utils.log_debug("No user prompt in event")
        return {
            "decision": "approve",
            "reason": "No user prompt to analyze",
            "continue": True,
        }

    _jj_utils.log_debug(f"Analyzing prompt: {user_prompt[:100]}...")

    # Check for uncommitted changes
    status = _jj_utils.get_jj_status()
    if not status["has_changes"]:
        _jj_utils.log_debug("No uncommitted changes - approving")
        return {
            "decision": "approve",
            "reason": "No uncommitted changes to commit",
            "continue": True,
        }

    # Get current commit info
    current_desc = _jj_utils.get_current_commit_description()
    file_count = status["file_count"]

    _jj_utils.log_debug(
        f"Found {file_count} uncommitted files, current description: {current_desc!r}"
    )

    # Detect scope shift
    is_scope_shift, shift_reason = _jj_utils.detect_scope_shift(user_prompt)

    if not is_scope_shift:
        # No scope shift → continue working on current commit
        _jj_utils.log_debug(f"No scope shift detected: {shift_reason}")
        return {
            "decision": "approve",
            "reason": f"Continuing current work: {shift_reason}",
            "continue": True,
        }

    # Scope shift detected with uncommitted changes
    _jj_utils.log_debug(f"Scope shift detected: {shift_reason}")

    # Decision: Auto-commit or Advisory?
    if current_desc is None and file_count > 5:
        # Many uncommitted files without description → suggest manual commit
        _jj_utils.log_debug("Advisory: Too many files without description")
        return {
            "decision": "approve",
            "reason": "Advisory: Suggest manual commit for large changeset",
            "continue": True,
            "systemMessage": (
                f"⚠️  Detected scope shift in user request, but you have {file_count} uncommitted "
                f"files without a commit description. Consider using `/jj:commit` or `/jj:split` "
                f"before starting new work to avoid cluttered commits."
            ),
        }

    # Auto-commit scenario: scope shift + reasonable changeset
    _jj_utils.log_debug(f"Auto-committing {file_count} files before new work")

    # Generate commit message with jj-ai-desc
    success, message = _jj_utils.call_jj_ai_desc("@")

    if not success:
        _jj_utils.log_debug(f"jj-ai-desc failed: {message}")
        return {
            "decision": "approve",
            "reason": "Advisory: Auto-commit failed, suggesting manual commit",
            "continue": True,
            "systemMessage": (
                f"⚠️  Detected scope shift. Attempted to auto-commit {file_count} files but "
                f"jj-ai-desc failed: {message}. Consider committing manually before proceeding."
            ),
        }

    # Commit was successful (jj-ai-desc calls jj describe internally)
    _jj_utils.log_debug(f"Generated commit message: {message[:50]}...")

    # Create new empty commit for upcoming work
    returncode, stdout, stderr = _jj_utils.run_jj_command(["new"], check=False)
    if returncode != 0:
        _jj_utils.log_debug(f"jj new failed: {stderr}")
        system_msg = (
            f"✅ Auto-committed previous work: {message[:60]}...\n"
            f"⚠️  Failed to create new commit (jj new). You may want to run it manually."
        )
    else:
        _jj_utils.log_debug("Created new empty commit with jj new")
        system_msg = (
            f"✅ Auto-committed previous work ({file_count} files) and created new commit for this task.\n"
            f"Commit: {message[:80]}{'...' if len(message) > 80 else ''}"
        )

    return {
        "decision": "approve",
        "reason": f"Auto-committed previous work due to scope shift: {shift_reason}",
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
    UserPromptSubmit Hook: Intelligent commit boundary detection.

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
        response = process_user_prompt_event(event)

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
from unittest.mock import patch, Mock

runner = CliRunner()


class TestUserPromptCommitIntegration:
    """REAL integration tests using CliRunner - tests full execution path."""

    def test_no_uncommitted_changes_via_cli(self):
        """INTEGRATION: Full CLI execution with no changes."""

        with patch("_jj_utils.get_jj_status") as mock_status:
            # Setup: no changes
            mock_status.return_value = {"has_changes": False, "file_count": 0}

            # Invoke CLI
            event = {"prompt": "Now let's add a new feature"}
            result = runner.invoke(app, [json.dumps(event)])

            # Verify
            assert result.exit_code == 0
            response = json.loads(result.stdout)
            assert response["decision"] == "approve"
            assert "No uncommitted changes" in response["reason"]

    def test_scope_shift_triggers_auto_commit(self):
        """INTEGRATION: Scope shift with changes should auto-commit."""

        with (
            patch("_jj_utils.get_jj_status") as mock_status,
            patch("_jj_utils.get_current_commit_description") as mock_desc,
            patch("_jj_utils.call_jj_ai_desc") as mock_ai,
            patch("_jj_utils.run_jj_command") as mock_jj,
        ):
            # Setup mocks
            mock_status.return_value = {"has_changes": True, "file_count": 2}
            mock_desc.return_value = "existing description"
            mock_ai.return_value = (True, "feat: add new feature")
            mock_jj.return_value = (0, "", "")

            # Invoke with scope shift prompt
            event = {"prompt": "Now let's add authentication"}
            result = runner.invoke(app, [json.dumps(event)])

            # Verify exit and response
            assert result.exit_code == 0
            response = json.loads(result.stdout)
            assert response["decision"] == "approve"
            assert "Auto-committed" in response["systemMessage"]

            # Verify jj-ai-desc was called
            mock_ai.assert_called_once_with("@")

            # Verify jj new was called
            mock_jj.assert_called_once_with(["new"], check=False)

    def test_no_scope_shift_continues_work(self):
        """INTEGRATION: No scope shift should approve continuation."""

        with patch("_jj_utils.get_jj_status") as mock_status:
            mock_status.return_value = {"has_changes": True, "file_count": 2}

            # Prompt without scope shift
            event = {"prompt": "Can you help me with this?"}
            result = runner.invoke(app, [json.dumps(event)])

            assert result.exit_code == 0
            response = json.loads(result.stdout)
            assert response["decision"] == "approve"
            assert "Continuing current work" in response["reason"]

    def test_advisory_for_many_files_without_description(self):
        """INTEGRATION: Many files without description should give advisory."""

        with (
            patch("_jj_utils.get_jj_status") as mock_status,
            patch("_jj_utils.get_current_commit_description") as mock_desc,
        ):
            mock_status.return_value = {"has_changes": True, "file_count": 10}
            mock_desc.return_value = None  # No description

            event = {"prompt": "Now let's add auth"}
            result = runner.invoke(app, [json.dumps(event)])

            assert result.exit_code == 0
            response = json.loads(result.stdout)
            assert response["decision"] == "approve"
            assert "systemMessage" in response
            assert "Detected scope shift" in response["systemMessage"]
            assert "/jj:commit" in response["systemMessage"]

    def test_stdin_input(self):
        """INTEGRATION: Reading event from stdin."""

        with patch("_jj_utils.get_jj_status") as mock_status:
            mock_status.return_value = {"has_changes": False, "file_count": 0}

            event = {"prompt": "Test prompt"}
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

    def test_jj_ai_desc_failure_handling(self):
        """INTEGRATION: jj-ai-desc failure should provide advisory."""

        with (
            patch("_jj_utils.get_jj_status") as mock_status,
            patch("_jj_utils.get_current_commit_description") as mock_desc,
            patch("_jj_utils.call_jj_ai_desc") as mock_ai,
        ):
            mock_status.return_value = {"has_changes": True, "file_count": 2}
            mock_desc.return_value = "some desc"
            mock_ai.return_value = (False, "jj-ai-desc not found")

            event = {"prompt": "Now let's add auth"}
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
            patch("_jj_utils.call_jj_ai_desc") as mock_ai,
            patch("_jj_utils.run_jj_command") as mock_jj,
        ):
            mock_status.return_value = {"has_changes": True, "file_count": 2}
            mock_desc.return_value = "desc"
            mock_ai.return_value = (True, "feat: add feature")
            mock_jj.return_value = (1, "", "jj new failed")  # Failure!

            event = {"prompt": "Now add auth"}
            result = runner.invoke(app, [json.dumps(event)])

            assert result.exit_code == 0
            response = json.loads(result.stdout)
            assert "Auto-committed" in response["systemMessage"]
            assert "Failed to create new commit" in response["systemMessage"]


class TestBusinessLogic:
    """Unit tests for business logic function."""

    def test_process_no_prompt(self):
        """UNIT: Empty prompt should approve."""
        event = {"prompt": ""}
        response = process_user_prompt_event(event)
        assert response["decision"] == "approve"
        assert "No user prompt" in response["reason"]

    def test_process_no_changes(self, monkeypatch):
        """UNIT: No uncommitted changes should approve."""

        def mock_status():
            return {"has_changes": False, "file_count": 0}

        monkeypatch.setattr("_jj_utils.get_jj_status", mock_status)

        event = {"prompt": "Test"}
        response = process_user_prompt_event(event)
        assert response["decision"] == "approve"
        assert "No uncommitted changes" in response["reason"]


if __name__ == "__main__":
    app()
