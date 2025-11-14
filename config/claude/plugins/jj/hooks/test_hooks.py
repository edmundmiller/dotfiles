#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["pytest"]
# ///
"""
Test Claude Code hooks for jj plugin.

Minimal focused tests for hook functionality:
- JSON output validation
- Git command blocking/allowing
- Hook integration testing

Run directly: ./test_hooks.py
Or via pytest: pytest test_hooks.py -v
"""

import json
import subprocess
import sys
from pathlib import Path

import pytest


# ============================================================================
# FIXTURES
# ============================================================================


@pytest.fixture
def hooks_dir():
    """Get the hooks directory path."""
    return Path(__file__).parent


@pytest.fixture
def git_translator(hooks_dir):
    """Path to git-to-jj-translator.py hook."""
    return hooks_dir / "git-to-jj-translator.py"


# ============================================================================
# TESTS: Git Command Translator
# ============================================================================


def test_git_translator_blocks_write_commands(git_translator):
    """Git write commands should be blocked with jj alternatives."""
    write_commands = [
        "git commit -m 'test'",
        "git add .",
        "git push",
        "git pull",
        "git merge main",
    ]

    for cmd in write_commands:
        event = {"tool": {"name": "Bash", "params": {"command": cmd}}}
        result = subprocess.run(
            [str(git_translator)],
            input=json.dumps(event),
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0, f"Hook failed for: {cmd}"
        response = json.loads(result.stdout)

        # Should block the command
        assert response["continue"] is False, f"Should block: {cmd}"
        assert "system_message" in response, f"Should provide message for: {cmd}"
        assert "jj" in response["system_message"].lower(), (
            f"Should suggest jj for: {cmd}"
        )


def test_git_translator_allows_read_commands(git_translator):
    """Git read-only commands should be allowed."""
    read_commands = [
        "git log",
        "git show HEAD",
        "git diff",
        "git status",
        "git branch",
    ]

    for cmd in read_commands:
        event = {"tool": {"name": "Bash", "params": {"command": cmd}}}
        result = subprocess.run(
            [str(git_translator)],
            input=json.dumps(event),
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0, f"Hook failed for: {cmd}"
        response = json.loads(result.stdout)

        # Should allow the command
        assert response["continue"] is True, f"Should allow: {cmd}"
        assert "system_message" not in response, f"Should not block: {cmd}"


def test_git_translator_ignores_non_bash_tools(git_translator):
    """Non-Bash tools should be ignored."""
    event = {"tool": {"name": "Edit", "params": {"file_path": "test.py"}}}
    result = subprocess.run(
        [str(git_translator)],
        input=json.dumps(event),
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0
    response = json.loads(result.stdout)
    assert response["continue"] is True


def test_git_translator_ignores_non_git_commands(git_translator):
    """Non-git Bash commands should be ignored."""
    event = {"tool": {"name": "Bash", "params": {"command": "ls -la"}}}
    result = subprocess.run(
        [str(git_translator)],
        input=json.dumps(event),
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0
    response = json.loads(result.stdout)
    assert response["continue"] is True


def test_git_translator_returns_valid_json(git_translator):
    """Hook should always return valid JSON."""
    test_cases = [
        {"tool": {"name": "Bash", "params": {"command": "git commit"}}},
        {"tool": {"name": "Bash", "params": {"command": "git log"}}},
        {"tool": {"name": "Bash", "params": {"command": "ls"}}},
        {"tool": {"name": "Edit", "params": {}}},
    ]

    for event in test_cases:
        result = subprocess.run(
            [str(git_translator)],
            input=json.dumps(event),
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0
        # Should parse as valid JSON
        response = json.loads(result.stdout)
        # Should have continue field
        assert "continue" in response
        assert isinstance(response["continue"], bool)


# ============================================================================
# TESTS: User Prompt Hook
# ============================================================================


def test_user_prompt_hook_returns_valid_json(hooks_dir):
    """UserPromptSubmit hook should return valid JSON structure."""
    hook = hooks_dir / "user-prompt-commit.py"

    event = {"userMessage": "Can you help me test this?"}
    result = subprocess.run(
        [str(hook)],
        input=json.dumps(event),
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0
    response = json.loads(result.stdout)

    # Should have required fields
    assert "decision" in response
    assert "reason" in response
    assert "continue" in response

    # Decision should be valid
    assert response["decision"] in ["approve", "deny"]
    assert isinstance(response["continue"], bool)


# ============================================================================
# SELF-EXECUTION
# ============================================================================

if __name__ == "__main__":
    # Run pytest with verbose output
    sys.exit(pytest.main([__file__, "-v"]))
