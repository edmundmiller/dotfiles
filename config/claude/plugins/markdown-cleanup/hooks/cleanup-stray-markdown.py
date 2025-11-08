#!/usr/bin/env -S uv run --script
# /// script
# dependencies = []
# [tool.uv]
# exclude-newer = "2025-08-23T00:00:00Z"
# ///
"""
Markdown Cleanup Hook

Automatically removes stray markdown files created during Claude Code sessions.
This hook runs after Claude responds to prevent accumulation of temporary files.
"""

import sys
from pathlib import Path
from typing import List


# Important markdown files that should NEVER be deleted
SAFELIST_EXACT = {
    "README.md",
    "CLAUDE.md",
    "CHANGELOG.md",
    "CONTRIBUTING.md",
    "LICENSE.md",
    "TODO.md",
    "NOTES.md",
    "INDEX.md",
}

# Directories that should be completely skipped
SAFELIST_DIRS = {
    "docs",
    "documentation",
    ".github",
    "node_modules",
    "vendor",
    ".git",
}

# Patterns that indicate a temporary file (case-insensitive)
TEMP_PATTERNS = [
    "temp_",
    "tmp_",
    "test_",
    "_test",
    "_temp",
    "_tmp",
    "scratch",
    "debug_",
    "output_",
]


def is_important_file(file_path: Path) -> bool:
    """
    Check if a markdown file is important and should be preserved.

    Args:
        file_path: Path to the markdown file

    Returns:
        True if the file should be preserved, False if it can be deleted
    """
    filename_upper = file_path.name.upper()

    # Check if filename is in safelist (exact match)
    if file_path.name in SAFELIST_EXACT:
        return True

    # Check for important name patterns (case-insensitive)
    important_patterns = ["README", "CHANGELOG", "LICENSE", "CONTRIBUTING"]
    if any(pattern in filename_upper for pattern in important_patterns):
        return True

    # Check if file is in a protected directory
    for parent in file_path.parents:
        if parent.name in SAFELIST_DIRS:
            return True

    return False


def is_temp_file(file_path: Path) -> bool:
    """
    Check if a markdown file looks like a temporary file.

    Args:
        file_path: Path to the markdown file

    Returns:
        True if the file looks temporary, False otherwise
    """
    filename_lower = file_path.name.lower()

    # Check if filename matches temporary patterns
    for pattern in TEMP_PATTERNS:
        if pattern in filename_lower:
            return True

    return False


def get_session_start_time() -> float:
    """
    Get the session start time from the timestamp file.

    Returns:
        Unix timestamp of session start, or 0 if not found
    """
    timestamp_file = Path("/tmp") / ".claude_session_start"

    if timestamp_file.exists():
        try:
            return float(timestamp_file.read_text().strip())
        except (ValueError, OSError):
            pass

    # If no timestamp file, consider files from last hour
    import time

    return time.time() - 3600


def is_documentation_path(file_path: Path) -> bool:
    """
    Check if a file is in a documentation directory.

    Args:
        file_path: Path to check

    Returns:
        True if file is in docs/, .github/, or similar
    """
    doc_dirs = {"docs", "documentation", ".github", "wiki"}

    for parent in file_path.parents:
        if parent.name in doc_dirs:
            return True

    return False


def find_stray_markdown_files() -> List[Path]:
    """
    Find markdown files created during this Claude Code session.

    Returns:
        List of Path objects for files that should be cleaned up
    """
    candidates = []
    session_start = get_session_start_time()

    # Get current working directory (repository root)
    cwd = Path.cwd()

    # Check repository root for markdown files created during session
    try:
        for md_file in cwd.glob("*.md"):
            # Skip if file is important
            if is_important_file(md_file):
                continue

            # Skip if file is in documentation path
            if is_documentation_path(md_file):
                continue

            # Check if file was created/modified during this session
            try:
                file_mtime = md_file.stat().st_mtime
                if file_mtime >= session_start:
                    candidates.append(md_file)
            except OSError:
                continue

    except (PermissionError, OSError):
        # Skip if we can't read the directory
        pass

    # Also check /tmp and /private/tmp (macOS)
    temp_dirs = [
        Path("/tmp"),
        Path("/private/tmp"),
    ]

    for temp_dir in temp_dirs:
        if not temp_dir.exists():
            continue

        try:
            # Find all .md files in temp directory created during session
            for md_file in temp_dir.glob("*.md"):
                if not md_file.is_file() or is_important_file(md_file):
                    continue

                try:
                    file_mtime = md_file.stat().st_mtime
                    if file_mtime >= session_start:
                        candidates.append(md_file)
                except OSError:
                    continue

        except (PermissionError, OSError):
            # Skip directories we can't read
            continue

    return candidates


def cleanup_files(files: List[Path]) -> dict:
    """
    Remove the specified files and return statistics.

    Args:
        files: List of file paths to remove

    Returns:
        Dictionary with cleanup statistics
    """
    removed = []
    errors = []

    for file_path in files:
        try:
            file_path.unlink()
            removed.append(str(file_path))
        except Exception as e:
            errors.append(f"{file_path}: {str(e)}")

    return {"removed": removed, "errors": errors, "count": len(removed)}


def main():
    """Main hook entry point."""
    try:
        # Find stray markdown files
        stray_files = find_stray_markdown_files()

        if not stray_files:
            # No files to clean up, silent operation
            sys.exit(0)

        # Clean up the files
        stats = cleanup_files(stray_files)

        # Report cleanup results if any files were removed
        if stats["count"] > 0:
            message = f"🧹 Cleaned up {stats['count']} stray markdown file(s)"
            if stats["errors"]:
                message += f" (with {len(stats['errors'])} error(s))"
            print(message)

        sys.exit(0)

    except Exception:
        # On any error, fail silently to avoid breaking Claude
        # Uncomment for debugging: print(f"Markdown cleanup error: {str(e)}")
        sys.exit(0)


if __name__ == "__main__":
    main()
