#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "typer",
#     "rich",
#     "toon-format @ git+https://github.com/toon-format/toon-python.git",
# ]
# ///

# =============================================================================
# AI-NAVIGATION: Use ast-grep for precise structural search
# =============================================================================
# Find specific functions and code structures:
#
#   ast-grep --pattern 'def main($$$)' jj-ai-desc.py
#   ast-grep --pattern 'def strip_markdown_fences($$$)' jj-ai-desc.py
#   ast-grep --pattern 'def run_command($$$)' jj-ai-desc.py
#   ast-grep --pattern '@app.command()' jj-ai-desc.py
#   ast-grep --pattern 'if __name__ == "__main__"' jj-ai-desc.py
#
# List all function definitions:
#   ast-grep --pattern 'def $FUNC($$$)' jj-ai-desc.py
#
# Section markers (use with Read tool + line offset):
#   Line 86:  # AI-SEARCH: HELPERS (helper functions)
#   Line 135: # AI-SEARCH: MAIN (main CLI logic)
#   Line 291: # AI-SEARCH: TESTS (35 test functions)
#   Line 565: # AI-SEARCH: ENTRY (entry point)
# =============================================================================

"""
jj-ai-desc - AI-Powered Commit Message Generator for Jujutsu

An intelligent commit message generator that uses Claude AI to create
conventional commit messages based on your diff and recent commit history.

Usage:
    jj-ai-desc              # Generate message for current commit
    jj-ai-desc -e           # Generate and open editor
    jj-ai-desc -r @-        # Generate for parent commit

Features:
    - Analyzes git diff and recent commit history for context
    - Generates conventional commit messages (feat/fix/refactor/docs/test/chore/style/perf)
    - Automatically strips markdown fences from Claude output
    - Rich progress display with status updates
    - Comprehensive error handling
    - 35 comprehensive tests covering all functionality

Running Tests:
    cd bin && uvx --with typer --with rich --with pytest pytest jj-ai-desc.py -v

Dependencies:
    - typer: CLI framework
    - rich: Terminal formatting and progress display
    - uv: Package management and execution
    - Claude CLI: ~/.local/bin/claude
    - jujutsu: jj command

Test Coverage (35 tests):
    - Markdown fence stripping (10 tests)
    - Conventional commit validation (3 tests)
    - Edge cases: long messages, special chars, unicode (6 tests)
    - Claude output handling (4 tests)
    - Real-world scenarios (4 tests)
    - Error recovery (3 tests)
    - Command execution (3 tests)
    - Character limit awareness (3 tests)
"""

import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Annotated, Optional

import typer
from rich.console import Console
from toon_format import encode as toon_encode

app = typer.Typer()
console = Console()


# ============================================================================
# AI-SEARCH: HELPERS
# Testable Helper Functions
# ============================================================================


def strip_markdown_fences(text: str) -> str:
    """
    Remove markdown code fences from text.

    Handles:
    - Opening fence with optional language identifier: ```python or ```
    - Closing fence: ```
    - Multiple fence blocks
    - Trailing whitespace
    """
    # Remove opening fence with optional language
    result = re.sub(r"^```[\w]*\n?", "", text, flags=re.MULTILINE)
    # Remove closing fence
    result = re.sub(r"^```\n?$", "", result, flags=re.MULTILINE)
    return result.strip()


def run_command(
    cmd: list[str], stdin_input: Optional[str] = None
) -> tuple[str, str, int]:
    """
    Run a command and return (stdout, stderr, exit_code).

    Args:
        cmd: Command and arguments to execute
        stdin_input: Optional string to pass to stdin

    Returns:
        Tuple of (stdout, stderr, exit_code)
    """
    try:
        result = subprocess.run(
            cmd,
            input=stdin_input,
            capture_output=True,
            text=True,
            check=False,
        )
        return result.stdout, result.stderr, result.returncode
    except Exception as e:
        return "", str(e), 1


# ============================================================================
# AI-SEARCH: MAIN
# Main Application Logic
# ============================================================================


@app.command()
def main(
    revision: Annotated[
        str, typer.Option("--revision", "-r", help="Revision to describe (default: @)")
    ] = "@",
    edit: Annotated[
        bool, typer.Option("--edit", "-e", help="Open editor after generating message")
    ] = False,
):
    """
    Generate AI-powered commit messages for jujutsu.

    Examples:
        jj-ai-desc              # Generate message for current commit
        jj-ai-desc -e           # Generate and open editor
        jj-ai-desc -r @-        # Generate for parent commit
    """

    # Step 1: Get the diff
    with console.status("[bold green]Getting diff..."):
        stdout, stderr, exit_code = run_command(["jj", "diff", "-r", revision])

    if exit_code != 0:
        console.print(f"[bold red]Error:[/bold red] Failed to get diff")
        console.print(f"[red]{stderr}[/red]")
        raise typer.Exit(1)

    diff_text = stdout

    if not diff_text.strip():
        console.print("[yellow]No changes to describe[/yellow]")
        raise typer.Exit(0)

    console.print("[bold green]✓[/bold green] Got diff")

    # Step 2: Get recent commit history for context
    with console.status("[bold green]Getting commit context..."):
        stdout, stderr, exit_code = run_command(
            [
                "jj",
                "log",
                "--no-graph",
                "-r",
                "ancestors(@-)",
                "--limit",
                "5",
                "-T",
                'commit_id.short() ++ "\\t" ++ description.first_line() ++ "\\n"',
            ]
        )

    commit_context = ""
    if exit_code == 0 and stdout.strip():
        # Parse the log output and format as TOON (40-60% token savings vs JSON)
        commits = []
        for line in stdout.strip().split("\n"):
            if not line.strip():
                continue
            parts = line.split("\t", 1)
            if len(parts) == 2:
                commit_id, message = parts
                commits.append(
                    {
                        "id": commit_id.strip(),
                        "message": message.strip(),
                    }
                )

        if commits:
            recent_commits = {"recent_commits": commits}
            toon_output = toon_encode(recent_commits)
            commit_context = (
                "Recent commit history for context (TOON format):\n"
                f"```\n{toon_output}\n```\n\n"
            )
            console.print(
                f"[bold green]✓[/bold green] Got {len(commits)} recent commits"
            )
        else:
            console.print("[yellow]⚠[/yellow] No recent commits found")
    else:
        console.print("[yellow]⚠[/yellow] Could not get commit history")

    # Step 3: Generate commit message
    with console.status("[bold green]Generating commit message..."):
        claude_path = Path.home() / ".local" / "bin" / "claude"

        if not claude_path.exists():
            console.print(
                f"[bold red]Error:[/bold red] Claude CLI not found at {claude_path}"
            )
            console.print(
                "\nInstall it with: "
                "curl -fsSL https://raw.githubusercontent.com/anthropics/claude-code/main/install.sh | sh"
            )
            raise typer.Exit(1)

        # Combine commit context and diff for Claude
        claude_input = commit_context + f"Here is the diff to describe:\n\n{diff_text}"

        stdout, stderr, exit_code = run_command(
            [
                str(claude_path),
                "-p",
                "Generate ONLY a conventional commit message (feat/fix/refactor/docs/test/chore/style/perf) "
                "for this diff. Consider the style and context of recent commits. "
                "Output the message and nothing else. Keep it under 72 chars.",
                "--model",
                "haiku",
                "--output-format",
                "text",
                "--tools",
                "",
            ],
            stdin_input=claude_input,
        )

        if exit_code != 0:
            console.print(
                "[bold red]Error:[/bold red] Failed to generate commit message"
            )
            console.print(f"[red]{stderr}[/red]")
            raise typer.Exit(1)

        commit_message = strip_markdown_fences(stdout)

        if not commit_message:
            console.print(
                "[bold red]Error:[/bold red] Claude returned an empty commit message"
            )
            raise typer.Exit(1)

    console.print(f"[bold green]✓[/bold green] Generated: {commit_message}")

    # Step 4: Apply the commit message
    with console.status("[bold green]Applying commit message..."):
        # Use 'jj commit' for @ (working copy), 'jj describe' for other revisions
        # jj commit doesn't support -r, so we fallback to describe for non-@ revisions
        if revision == "@":
            jj_cmd = ["jj", "commit", "-m", commit_message]
            if edit:
                jj_cmd.append("--edit")
            stdout, stderr, exit_code = run_command(jj_cmd)
        else:
            jj_cmd = ["jj", "describe", "-r", revision]
            if edit:
                jj_cmd.append("--edit")
            jj_cmd.append("--stdin")
            stdout, stderr, exit_code = run_command(jj_cmd, stdin_input=commit_message)

        if exit_code != 0:
            console.print("[bold red]Error:[/bold red] Failed to apply commit message")
            console.print(f"[red]{stderr}[/red]")
            raise typer.Exit(1)

    if revision == "@":
        console.print(
            "[bold green]✓[/bold green] Committed and created new working copy"
        )
    else:
        console.print("[bold green]✓[/bold green] Commit message applied")


# ============================================================================
# AI-SEARCH: TESTS
# Tests (discovered by pytest, ignored during normal execution)
# ============================================================================


def test_strip_markdown_fences_with_language():
    """Should strip markdown fences with language identifier"""
    input_text = "```typescript\nfeat: add feature\n```"
    expected = "feat: add feature"
    assert strip_markdown_fences(input_text) == expected


def test_strip_markdown_fences_without_language():
    """Should strip markdown fences without language identifier"""
    input_text = "```\nfix: bug fix\n```"
    expected = "fix: bug fix"
    assert strip_markdown_fences(input_text) == expected


def test_strip_multiple_fences():
    """Should strip multiple markdown fence blocks"""
    input_text = "```\nfeat: first\n```\nSome text\n```\nfeat: second\n```"
    expected = "feat: first\nSome text\nfeat: second"
    assert strip_markdown_fences(input_text) == expected


def test_strip_fences_at_start():
    """Should handle markdown fences at start of string"""
    input_text = "```\nchore: update\n```"
    expected = "chore: update"
    assert strip_markdown_fences(input_text) == expected


def test_strip_fences_at_end():
    """Should handle markdown fences at end of string"""
    input_text = "Some text\n```\nrefactor: cleanup\n```"
    expected = "Some text\nrefactor: cleanup"
    assert strip_markdown_fences(input_text) == expected


def test_strip_no_fences():
    """Should handle text without markdown fences"""
    input_text = "feat: no fences here"
    assert strip_markdown_fences(input_text) == input_text


def test_strip_empty_string():
    """Should handle empty string"""
    assert strip_markdown_fences("") == ""


def test_strip_fence_with_trailing_newline():
    """Should handle fence with trailing newline"""
    input_text = "```\nfix: something\n```\n"
    expected = "fix: something"
    assert strip_markdown_fences(input_text) == expected


def test_strip_multiple_languages():
    """Should handle fence with multiple languages"""
    input_text = "```bash\nfix: first\n```\n```typescript\nfeat: second\n```"
    expected = "fix: first\nfeat: second"
    assert strip_markdown_fences(input_text) == expected


def test_strip_incomplete_fences():
    """Should handle incomplete fences gracefully"""
    input_text = "```\nfeat: incomplete"
    result = strip_markdown_fences(input_text)
    assert "```" not in result


def test_conventional_commit_prefixes():
    """Should accept all conventional commit prefixes"""
    prefixes = ["feat", "fix", "refactor", "docs", "test", "chore", "style", "perf"]

    for prefix in prefixes:
        message = f"{prefix}: some change"
        cleaned = strip_markdown_fences(f"```\n{message}\n```")
        assert cleaned == message
        assert cleaned.startswith(f"{prefix}:")


def test_conventional_commit_with_scope():
    """Should handle scope in conventional commits"""
    message = "feat(api): add new endpoint"
    cleaned = strip_markdown_fences(f"```\n{message}\n```")
    assert cleaned == message
    assert re.match(r"^feat\([^)]+\):", cleaned)


def test_conventional_commit_breaking_change():
    """Should handle breaking change indicator"""
    message = "feat!: breaking change"
    cleaned = strip_markdown_fences(f"```\n{message}\n```")
    assert cleaned == message
    assert re.match(r"^feat!:", cleaned)


def test_long_commit_message():
    """Should handle very long commit messages"""
    long_message = "feat: " + "a" * 200
    input_text = f"```\n{long_message}\n```"
    cleaned = strip_markdown_fences(input_text)
    assert cleaned == long_message
    assert len(cleaned) > 72


def test_special_characters():
    """Should handle commit messages with special characters"""
    message = 'fix: handle "quotes" and (parentheses) & ampersands'
    input_text = f"```\n{message}\n```"
    assert strip_markdown_fences(input_text) == message


def test_unicode():
    """Should handle commit messages with unicode"""
    message = "feat: add emoji support"
    input_text = f"```\n{message}\n```"
    assert strip_markdown_fences(input_text) == message


def test_multiline_commit():
    """Should handle multi-line commit messages"""
    message = "feat: add feature\n\nThis adds a new feature\nwith multiple lines"
    input_text = f"```\n{message}\n```"
    cleaned = strip_markdown_fences(input_text)
    assert "feat: add feature" in cleaned
    assert "This adds a new feature" in cleaned


def test_commit_with_code_in_body():
    """Should handle commit message with code in body"""
    message = "fix: update logic\n\nChanged `if (x)` to `if (y)`"
    input_text = f"```\n{message}\n```"
    cleaned = strip_markdown_fences(input_text)
    assert "fix: update logic" in cleaned
    assert "`if (x)`" in cleaned


def test_claude_code_fence_output():
    """Should handle Claude wrapping output in code fence"""
    actual_message = "feat: add AI commit message generation"
    claude_output = f"```\n{actual_message}\n```"
    assert strip_markdown_fences(claude_output) == actual_message


def test_claude_language_identifier():
    """Should handle Claude adding language identifier"""
    actual_message = "refactor: extract AI commit generation to script"
    claude_output = f"```text\n{actual_message}\n```"
    assert strip_markdown_fences(claude_output) == actual_message


def test_claude_extra_whitespace():
    """Should handle Claude output with extra whitespace"""
    actual_message = "chore: update dependencies"
    claude_output = f"```\n  {actual_message}  \n```"
    cleaned = strip_markdown_fences(claude_output)
    assert cleaned == actual_message


def test_claude_plain_text():
    """Should handle plain text output from Claude"""
    message = "docs: update README"
    assert strip_markdown_fences(message) == message


def test_real_world_feat():
    """Should handle typical feat commit"""
    claude_output = """```
feat: add jjui keybindings for AI commit generation
```"""
    cleaned = strip_markdown_fences(claude_output)
    assert cleaned == "feat: add jjui keybindings for AI commit generation"
    assert len(cleaned) <= 72


def test_real_world_fix():
    """Should handle typical fix commit"""
    claude_output = """```
fix: strip markdown fences from Claude output
```"""
    cleaned = strip_markdown_fences(claude_output)
    assert cleaned == "fix: strip markdown fences from Claude output"


def test_real_world_refactor():
    """Should handle typical refactor commit"""
    claude_output = """```typescript
refactor: replace Python script with Bun TypeScript version
```"""
    cleaned = strip_markdown_fences(claude_output)
    assert cleaned == "refactor: replace Python script with Bun TypeScript version"


def test_real_world_chore():
    """Should handle chore commit"""
    claude_output = "chore: update jj config to point to new script"
    cleaned = strip_markdown_fences(claude_output)
    assert cleaned == "chore: update jj config to point to new script"


def test_72_char_limit_exact():
    """Should handle commits at exactly 72 chars"""
    message = "feat: " + "x" * 66  # 6 + 66 = 72
    assert len(message) == 72
    cleaned = strip_markdown_fences(f"```\n{message}\n```")
    assert len(cleaned) == 72


def test_72_char_under():
    """Should handle commits under 72 chars"""
    message = "feat: short message"
    assert len(message) < 72
    cleaned = strip_markdown_fences(f"```\n{message}\n```")
    assert len(cleaned) < 72


def test_72_char_over():
    """Should not enforce 72 char limit (just strip fences)"""
    long_message = "feat: " + "x" * 100
    assert len(long_message) > 72
    cleaned = strip_markdown_fences(f"```\n{long_message}\n```")
    assert cleaned == long_message


def test_claude_empty_output():
    """Should handle Claude returning empty string"""
    claude_output = "```\n\n```"
    cleaned = strip_markdown_fences(claude_output)
    assert cleaned == ""


def test_claude_whitespace_only():
    """Should handle Claude returning only whitespace"""
    claude_output = "```\n   \n```"
    cleaned = strip_markdown_fences(claude_output)
    assert cleaned == ""


def test_malformed_fences():
    """Should handle malformed markdown fences"""
    message = "feat: test"
    malformed = f"``{message}``"  # Only 2 backticks
    # Should not crash
    try:
        strip_markdown_fences(malformed)
    except Exception as e:
        pytest.fail(f"strip_markdown_fences raised {e} unexpectedly")


def test_run_command_success():
    """Should run command successfully"""
    stdout, stderr, exit_code = run_command(["echo", "test"])
    assert exit_code == 0
    assert "test" in stdout
    assert stderr == ""


def test_run_command_with_stdin():
    """Should run command with stdin input"""
    stdout, stderr, exit_code = run_command(["cat"], stdin_input="hello world")
    assert exit_code == 0
    assert stdout.strip() == "hello world"


def test_run_command_failure():
    """Should handle command failure"""
    stdout, stderr, exit_code = run_command(["false"])
    assert exit_code != 0


# ============================================================================
# AI-SEARCH: ENTRY
# Entry Point
# ============================================================================

if __name__ == "__main__":
    app()
