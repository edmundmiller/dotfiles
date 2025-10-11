#!/usr/bin/env -S uv run --script
# /// script
# dependencies = []
# [tool.uv]
# exclude-newer = "2025-08-23T00:00:00Z"
# ///
"""
Session Start Tracker

Records the session start time for cleanup tracking.
Runs once at the beginning of each Claude Code session.
"""

import time
from pathlib import Path


def main():
    """Record session start time."""
    timestamp_file = Path("/tmp") / ".claude_session_start"

    # Only create timestamp if it doesn't exist (beginning of session)
    if not timestamp_file.exists():
        timestamp_file.write_text(str(time.time()))


if __name__ == "__main__":
    main()
