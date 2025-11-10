#!/usr/bin/env -S uv run --script
# /// script
# dependencies = []
# [tool.uv]
# exclude-newer = "2025-08-23T00:00:00Z"
# ///
"""
Claude Lint Plugin: Real-time validation hook.

This hook runs after Write/Edit operations on plugin files and validates
them with claudelint, providing immediate feedback during development.
"""

import json
import sys
import subprocess
from pathlib import Path
from typing import Dict, List, Set


def log_debug(message: str):
    """Log debug message to stderr."""
    print(f"[claude-lint] {message}", file=sys.stderr)


def get_plugin_dir_from_path(file_path: str) -> str | None:
    """
    Extract the plugin directory from a file path.

    Args:
        file_path: Path to a file in a plugin directory

    Returns:
        Plugin directory path or None if not in a plugin
    """
    path = Path(file_path)
    parts = path.parts

    try:
        # Find 'plugins' in path
        plugins_idx = parts.index("plugins")
        # Plugin dir is the next part after 'plugins'
        if plugins_idx + 1 < len(parts):
            plugin_name = parts[plugins_idx + 1]
            # Reconstruct plugin directory path
            plugin_dir = Path(*parts[: plugins_idx + 2])
            return str(plugin_dir)
    except (ValueError, IndexError):
        pass

    return None


def run_claudelint(plugin_dir: str) -> tuple[bool, str]:
    """
    Run claudelint on a plugin directory.

    Args:
        plugin_dir: Path to plugin directory

    Returns:
        Tuple of (success: bool, output: str)
    """
    try:
        result = subprocess.run(
            ["uvx", "claudelint", plugin_dir],
            capture_output=True,
            text=True,
            timeout=30,
        )

        output = result.stdout + result.stderr
        success = result.returncode == 0

        return success, output

    except subprocess.TimeoutExpired:
        return False, f"Validation timeout for {plugin_dir}"
    except FileNotFoundError:
        return False, "uvx not found - claudelint cannot run"
    except Exception as e:
        return False, f"Error running claudelint: {str(e)}"


def format_validation_message(
    plugin_dirs: List[str], results: Dict[str, tuple[bool, str]]
) -> str:
    """
    Format validation results into a user-friendly message.

    Args:
        plugin_dirs: List of validated plugin directories
        results: Dict mapping plugin dir to (success, output) tuples

    Returns:
        Formatted message string
    """
    if not results:
        return ""

    lines = ["\n## Plugin Validation Results\n"]

    all_passed = all(success for success, _ in results.values())

    for plugin_dir in plugin_dirs:
        success, output = results.get(plugin_dir, (False, "No result"))
        status = "✅" if success else "❌"
        lines.append(f"{status} **{plugin_dir}**")

        if not success and output:
            # Show first few lines of error output
            error_lines = output.strip().split("\n")[:5]
            lines.append("```")
            lines.extend(error_lines)
            if len(output.strip().split("\n")) > 5:
                lines.append("... (truncated)")
            lines.append("```")

        lines.append("")

    if all_passed:
        lines.append("All plugin files passed validation! 🎉")
    else:
        lines.append(
            "⚠️ Some plugin files failed validation. Please review the errors above."
        )

    return "\n".join(lines)


def process_tool_batch_event(event: Dict) -> Dict:
    """
    Process ToolCallBatch:Callback event and validate modified plugin files.

    Args:
        event: Event data with tool call information

    Returns:
        Hook response dict
    """
    # Extract tool calls from event
    tool_calls = event.get("toolCalls", [])

    if not tool_calls:
        log_debug("No tool calls in event")
        return {
            "decision": "approve",
            "reason": "No tool calls to validate",
            "continue": True,
        }

    # Collect file paths from Write/Edit operations
    modified_files: Set[str] = set()

    for tool_call in tool_calls:
        tool_name = tool_call.get("name", "")
        if tool_name in ["Write", "Edit"]:
            params = tool_call.get("params", {})
            file_path = params.get("file_path")

            if file_path:
                modified_files.add(file_path)

    if not modified_files:
        log_debug("No plugin files modified")
        return {
            "decision": "approve",
            "reason": "No plugin files modified",
            "continue": True,
        }

    log_debug(f"Modified files: {modified_files}")

    # Get unique plugin directories
    plugin_dirs: Set[str] = set()
    for file_path in modified_files:
        plugin_dir = get_plugin_dir_from_path(file_path)
        if plugin_dir:
            plugin_dirs.add(plugin_dir)

    if not plugin_dirs:
        log_debug("No plugin directories found")
        return {
            "decision": "approve",
            "reason": "Modified files not in plugin directories",
            "continue": True,
        }

    log_debug(f"Validating plugin directories: {plugin_dirs}")

    # Run claudelint on each plugin directory
    results: Dict[str, tuple[bool, str]] = {}

    for plugin_dir in plugin_dirs:
        log_debug(f"Running claudelint on {plugin_dir}")
        success, output = run_claudelint(plugin_dir)
        results[plugin_dir] = (success, output)

        if success:
            log_debug(f"✅ {plugin_dir} passed validation")
        else:
            log_debug(f"❌ {plugin_dir} failed validation")

    # Format validation message
    sorted_dirs = sorted(plugin_dirs)
    message = format_validation_message(sorted_dirs, results)

    # Check if all validations passed
    all_passed = all(success for success, _ in results.values())

    if all_passed:
        return {
            "decision": "approve",
            "reason": "All plugin files validated successfully",
            "continue": True,
            "systemMessage": message,
        }
    else:
        # Don't block on validation failure (warnings only)
        # But provide feedback about the issues
        return {
            "decision": "approve",
            "reason": "Plugin validation completed with warnings",
            "continue": True,
            "systemMessage": message,
        }


def main():
    """Main entry point for the hook."""
    try:
        # Read event from stdin
        event_json = sys.stdin.read()

        if not event_json.strip():
            log_debug("No input received")
            response = {"decision": "approve", "reason": "No input", "continue": True}
        else:
            event = json.loads(event_json)
            response = process_tool_batch_event(event)

        # Output response as JSON
        print(json.dumps(response))
        sys.exit(0)

    except json.JSONDecodeError as e:
        log_debug(f"JSON decode error: {e}")
        print(
            json.dumps(
                {
                    "decision": "approve",
                    "reason": "Invalid input JSON",
                    "continue": True,
                }
            )
        )
        sys.exit(1)

    except Exception as e:
        log_debug(f"Error in hook: {e}")
        print(
            json.dumps(
                {
                    "decision": "approve",
                    "reason": f"Hook error: {str(e)}",
                    "continue": True,
                }
            )
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
