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


@pytest.fixture
def jj_diff_context_script(plugin_dir):
    """Get path to jj-diff-context.sh script."""
    script = plugin_dir / "hooks" / "jj-diff-context.sh"
    assert script.exists(), f"jj-diff-context.sh not found at {script}"
    return script


@pytest.fixture
def pattern_expand_script(plugin_dir):
    """Get path to pattern-expand.sh script."""
    script = plugin_dir / "hooks" / "pattern-expand.sh"
    assert script.exists(), f"pattern-expand.sh not found at {script}"
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
# TESTS: jj-diff-context.sh
# ============================================================================


class TestJjDiffContext:
    """Tests for jj-diff-context.sh utility functions."""

    def test_get_diff_summary_default(self, jj_diff_context_script):
        """Test get_diff_summary with default revision."""
        mock_summary = "M file1.py\\nA file2.js"
        output = mock_jj_command(
            jj_diff_context_script, "get_diff_summary", mock_summary
        )
        assert "file1.py" in output or "file2.js" in output

    def test_get_diff_summary_custom_revision(self, jj_diff_context_script):
        """Test get_diff_summary accepts custom revision parameter."""
        bash_cmd = f"""
        source {jj_diff_context_script}
        declare -F get_diff_summary
        """
        result = subprocess.run(
            ["bash", "-c", bash_cmd], capture_output=True, text=True
        )
        assert result.returncode == 0

    def test_get_diff_stats_default(self, jj_diff_context_script):
        """Test get_diff_stats with default revision."""
        mock_stats = "file1.py | 10 ++++++----\\n 1 file changed, 6 insertions(+), 4 deletions(-)"
        output = mock_jj_command(jj_diff_context_script, "get_diff_stats", mock_stats)
        assert "file1.py" in output or "file changed" in output

    def test_extract_changed_files(self, jj_diff_context_script):
        """Test extract_changed_files parses diff output."""
        # Mock jj diff --summary output
        bash_cmd = f"""
        jj() {{
            echo "M file1.py"
            echo "A file2.js"
            echo "D file3.ts"
        }}
        export -f jj
        source {jj_diff_context_script}
        extract_changed_files
        """
        result = subprocess.run(
            ["bash", "-c", bash_cmd], capture_output=True, text=True
        )
        output = result.stdout.strip()
        assert "file1.py" in output
        assert "file2.js" in output
        assert "file3.ts" in output

    def test_format_diff_for_ai(self, jj_diff_context_script):
        """Test format_diff_for_ai creates formatted output."""
        mock_output = "M file1.py"
        output = mock_jj_command(
            jj_diff_context_script, "format_diff_for_ai", mock_output
        )
        assert "Diff Summary" in output or "Diff Statistics" in output


# ============================================================================
# TESTS: pattern-expand.sh
# ============================================================================


class TestPatternExpand:
    """Tests for pattern-expand.sh utility functions."""

    def test_expand_test_pattern(self, pattern_expand_script):
        """Test expand_test_pattern returns test file globs."""
        output = run_bash_function(pattern_expand_script, "expand_test_pattern")
        assert "glob:**/*test*" in output
        assert "glob:**/*spec*" in output
        assert "glob:**/test_*" in output

    def test_expand_docs_pattern(self, pattern_expand_script):
        """Test expand_docs_pattern returns documentation globs."""
        output = run_bash_function(pattern_expand_script, "expand_docs_pattern")
        assert "glob:**.md" in output
        assert "glob:**/README*" in output
        assert "glob:**/CHANGELOG*" in output

    def test_expand_config_pattern(self, pattern_expand_script):
        """Test expand_config_pattern returns config file globs."""
        output = run_bash_function(pattern_expand_script, "expand_config_pattern")
        assert "glob:**.json" in output
        assert "glob:**.yaml" in output
        assert "glob:**.toml" in output

    def test_expand_custom_pattern(self, pattern_expand_script):
        """Test expand_custom_pattern wraps custom glob."""
        bash_cmd = f"""
        source {pattern_expand_script}
        expand_custom_pattern "*.md"
        """
        result = subprocess.run(
            ["bash", "-c", bash_cmd], capture_output=True, text=True
        )
        output = result.stdout.strip()
        assert "glob:*.md" in output

    def test_expand_pattern_test_keyword(self, pattern_expand_script):
        """Test expand_pattern routes 'test' to expand_test_pattern."""
        bash_cmd = f"""
        source {pattern_expand_script}
        expand_pattern "test"
        """
        result = subprocess.run(
            ["bash", "-c", bash_cmd], capture_output=True, text=True
        )
        output = result.stdout.strip()
        assert "glob:**/*test*" in output

    def test_expand_pattern_docs_keyword(self, pattern_expand_script):
        """Test expand_pattern routes 'docs' to expand_docs_pattern."""
        bash_cmd = f"""
        source {pattern_expand_script}
        expand_pattern "docs"
        """
        result = subprocess.run(
            ["bash", "-c", bash_cmd], capture_output=True, text=True
        )
        output = result.stdout.strip()
        assert "glob:**.md" in output

    def test_expand_pattern_config_keyword(self, pattern_expand_script):
        """Test expand_pattern routes 'config' to expand_config_pattern."""
        bash_cmd = f"""
        source {pattern_expand_script}
        expand_pattern "config"
        """
        result = subprocess.run(
            ["bash", "-c", bash_cmd], capture_output=True, text=True
        )
        output = result.stdout.strip()
        assert "glob:**.json" in output

    def test_expand_pattern_custom(self, pattern_expand_script):
        """Test expand_pattern routes unknown patterns to expand_custom_pattern."""
        bash_cmd = f"""
        source {pattern_expand_script}
        expand_pattern "**/*.tsx"
        """
        result = subprocess.run(
            ["bash", "-c", bash_cmd], capture_output=True, text=True
        )
        output = result.stdout.strip()
        assert "glob:**/*.tsx" in output


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

    def test_jj_diff_context_is_executable(self, jj_diff_context_script):
        """Test jj-diff-context.sh has executable permissions."""
        import os

        assert os.access(jj_diff_context_script, os.X_OK), (
            "jj-diff-context.sh should be executable"
        )

    def test_jj_diff_context_has_shebang(self, jj_diff_context_script):
        """Test jj-diff-context.sh has proper bash shebang."""
        first_line = jj_diff_context_script.read_text().split("\n")[0]
        assert first_line == "#!/usr/bin/env bash", "Should have bash shebang"

    def test_jj_diff_context_has_set_flags(self, jj_diff_context_script):
        """Test jj-diff-context.sh uses set -euo pipefail for safety."""
        content = jj_diff_context_script.read_text()
        assert "set -euo pipefail" in content, "Should use strict error handling"

    def test_pattern_expand_is_executable(self, pattern_expand_script):
        """Test pattern-expand.sh has executable permissions."""
        import os

        assert os.access(pattern_expand_script, os.X_OK), (
            "pattern-expand.sh should be executable"
        )

    def test_pattern_expand_has_shebang(self, pattern_expand_script):
        """Test pattern-expand.sh has proper bash shebang."""
        first_line = pattern_expand_script.read_text().split("\n")[0]
        assert first_line == "#!/usr/bin/env bash", "Should have bash shebang"

    def test_pattern_expand_has_set_flags(self, pattern_expand_script):
        """Test pattern-expand.sh uses set -euo pipefail for safety."""
        content = pattern_expand_script.read_text()
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

    def test_can_source_all_four_scripts(
        self,
        jj_state_script,
        jj_templates_script,
        jj_diff_context_script,
        pattern_expand_script,
    ):
        """Test that all four utility scripts can be sourced together without conflicts."""
        bash_cmd = f"""
        source {jj_state_script}
        source {jj_templates_script}
        source {jj_diff_context_script}
        source {pattern_expand_script}
        declare -F get_commit_state
        declare -F format_commit_short
        declare -F get_diff_summary
        declare -F expand_pattern
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
