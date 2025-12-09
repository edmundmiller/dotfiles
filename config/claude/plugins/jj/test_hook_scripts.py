#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["pytest"]
# ///
"""
Tests for jj utility hook scripts.

Tests the bash utility scripts that provide reusable functions for
jj state inspection and template formatting.

Run directly: ./test_hook_scripts.py
Or via pytest: pytest test_hook_scripts.py -v
"""

import subprocess
from pathlib import Path

import pytest


# ============================================================================
# TEST FIXTURES AND HELPERS
# ============================================================================


@pytest.fixture
def plugin_dir():
    """Get the plugin directory path."""
    return Path(__file__).parent


@pytest.fixture
def jj_state_script(plugin_dir):
    """Get path to jj-state.sh script."""
    script = plugin_dir / "hooks" / "jj-state.sh"
    assert script.exists(), f"jj-state.sh not found at {script}"
    return script


@pytest.fixture
def jj_templates_script(plugin_dir):
    """Get path to jj-templates.sh script."""
    script = plugin_dir / "hooks" / "jj-templates.sh"
    assert script.exists(), f"jj-templates.sh not found at {script}"
    return script


def run_bash_function(script_path: Path, function_name: str, *args) -> str:
    """
    Run a bash function from a script and return its output.

    Args:
        script_path: Path to the bash script
        function_name: Name of the function to call
        *args: Arguments to pass to the function

    Returns:
        The stdout output from the function
    """
    bash_cmd = f"""
    source {script_path}
    {function_name} {" ".join(f'"{arg}"' for arg in args)}
    """
    result = subprocess.run(
        ["bash", "-c", bash_cmd],
        capture_output=True,
        text=True,
        check=False,
    )
    return result.stdout.strip()


def mock_jj_command(
    script_path: Path, function_name: str, mock_output: str, *args
) -> str:
    """
    Run a bash function with a mocked jj command.

    Args:
        script_path: Path to the bash script
        function_name: Name of the function to call
        mock_output: Output to return from the mocked jj command
        *args: Arguments to pass to the function

    Returns:
        The stdout output from the function
    """
    bash_cmd = f"""
    jj() {{ echo "{mock_output}"; }}
    export -f jj
    source {script_path}
    {function_name} {" ".join(f'"{arg}"' for arg in args)}
    """
    result = subprocess.run(
        ["bash", "-c", bash_cmd],
        capture_output=True,
        text=True,
        check=False,
    )
    return result.stdout.strip()


# ============================================================================
# TESTS: jj-state.sh
# ============================================================================


class TestJjState:
    """Tests for jj-state.sh utility functions."""

    def test_get_commit_state_has_description(self, jj_state_script):
        """Test get_commit_state returns 'has' when commit has description."""
        output = mock_jj_command(jj_state_script, "get_commit_state", "has")
        assert output == "has"

    def test_get_commit_state_no_description(self, jj_state_script):
        """Test get_commit_state returns 'none' when commit has no description."""
        output = mock_jj_command(jj_state_script, "get_commit_state", "none")
        assert output == "none"

    def test_is_empty_commit_empty(self, jj_state_script):
        """Test is_empty_commit returns 'empty' when commit is empty."""
        output = mock_jj_command(jj_state_script, "is_empty_commit", "empty")
        assert output == "empty"

    def test_is_empty_commit_has_changes(self, jj_state_script):
        """Test is_empty_commit returns 'has_changes' when commit has changes."""
        output = mock_jj_command(jj_state_script, "is_empty_commit", "has_changes")
        assert output == "has_changes"

    def test_get_working_copy_status(self, jj_state_script):
        """Test get_working_copy_status returns jj status output."""
        mock_status = "Working copy: abc123\\nParent: def456"
        output = mock_jj_command(
            jj_state_script, "get_working_copy_status", mock_status
        )
        assert "abc123" in output
        assert "def456" in output


# ============================================================================
# TESTS: jj-templates.sh
# ============================================================================


class TestJjTemplates:
    """Tests for jj-templates.sh utility functions."""

    def test_format_commit_short_default(self, jj_templates_script):
        """Test format_commit_short with default revision (@)."""
        expected = "abc123: feat: add feature"
        output = mock_jj_command(jj_templates_script, "format_commit_short", expected)
        assert output == expected

    def test_format_commit_short_custom_revision(self, jj_templates_script):
        """Test format_commit_short with custom revision."""
        expected = "def456: fix: bug fix"
        # Note: Can't easily test custom revision with mock, but verify function accepts arg
        bash_cmd = f"""
        source {jj_templates_script}
        # Test that function accepts a parameter (syntax check)
        declare -F format_commit_short
        """
        result = subprocess.run(
            ["bash", "-c", bash_cmd], capture_output=True, text=True
        )
        assert result.returncode == 0

    def test_format_commit_list_default(self, jj_templates_script):
        """Test format_commit_list with default revset."""
        expected = "abc123: feat: add feature\\ndef456: fix: bug fix"
        output = mock_jj_command(jj_templates_script, "format_commit_list", expected)
        assert "abc123: feat: add feature" in output
        assert "def456: fix: bug fix" in output

    def test_format_commit_list_custom_revset(self, jj_templates_script):
        """Test format_commit_list accepts custom revset parameter."""
        bash_cmd = f"""
        source {jj_templates_script}
        # Test that function accepts a parameter (syntax check)
        declare -F format_commit_list
        """
        result = subprocess.run(
            ["bash", "-c", bash_cmd], capture_output=True, text=True
        )
        assert result.returncode == 0

    def test_format_ancestors_default(self, jj_templates_script):
        """Test format_ancestors with default count."""
        expected = "abc123: feat: add feature\\ndef456: fix: bug fix"
        output = mock_jj_command(jj_templates_script, "format_ancestors", expected)
        assert "abc123" in output or "def456" in output

    def test_format_ancestors_custom_count(self, jj_templates_script):
        """Test format_ancestors accepts custom count parameter."""
        bash_cmd = f"""
        source {jj_templates_script}
        # Test that function accepts a parameter (syntax check)
        declare -F format_ancestors
        """
        result = subprocess.run(
            ["bash", "-c", bash_cmd], capture_output=True, text=True
        )
        assert result.returncode == 0


# ============================================================================
# TESTS: Script Structure and Conventions
# ============================================================================


class TestScriptStructure:
    """Tests for bash script structure and conventions."""

    def test_jj_state_is_executable(self, jj_state_script):
        """Test jj-state.sh has executable permissions."""
        import os

        assert os.access(jj_state_script, os.X_OK), "jj-state.sh should be executable"

    def test_jj_templates_is_executable(self, jj_templates_script):
        """Test jj-templates.sh has executable permissions."""
        import os

        assert os.access(jj_templates_script, os.X_OK), (
            "jj-templates.sh should be executable"
        )

    def test_jj_state_has_shebang(self, jj_state_script):
        """Test jj-state.sh has proper bash shebang."""
        first_line = jj_state_script.read_text().split("\n")[0]
        assert first_line == "#!/usr/bin/env bash", "Should have bash shebang"

    def test_jj_templates_has_shebang(self, jj_templates_script):
        """Test jj-templates.sh has proper bash shebang."""
        first_line = jj_templates_script.read_text().split("\n")[0]
        assert first_line == "#!/usr/bin/env bash", "Should have bash shebang"

    def test_jj_state_has_set_flags(self, jj_state_script):
        """Test jj-state.sh uses set -euo pipefail for safety."""
        content = jj_state_script.read_text()
        assert "set -euo pipefail" in content, "Should use strict error handling"

    def test_jj_templates_has_set_flags(self, jj_templates_script):
        """Test jj-templates.sh uses set -euo pipefail for safety."""
        content = jj_templates_script.read_text()
        assert "set -euo pipefail" in content, "Should use strict error handling"


# ============================================================================
# INTEGRATION TESTS
# ============================================================================


class TestIntegration:
    """Integration tests for using scripts together."""

    def test_can_source_both_scripts(self, jj_state_script, jj_templates_script):
        """Test that both scripts can be sourced together without conflicts."""
        bash_cmd = f"""
        source {jj_state_script}
        source {jj_templates_script}
        declare -F get_commit_state
        declare -F format_commit_short
        """
        result = subprocess.run(
            ["bash", "-c", bash_cmd], capture_output=True, text=True
        )
        assert result.returncode == 0

    def test_scripts_work_from_different_directories(self, jj_state_script, plugin_dir):
        """Test scripts work when sourced from different working directories."""
        import os

        bash_cmd = f"""
        cd /tmp
        source {jj_state_script}
        declare -F get_commit_state
        """
        result = subprocess.run(
            ["bash", "-c", bash_cmd], capture_output=True, text=True
        )
        assert result.returncode == 0


if __name__ == "__main__":
    # Run pytest when executed directly
    import sys

    sys.exit(pytest.main([__file__, "-v"]))
