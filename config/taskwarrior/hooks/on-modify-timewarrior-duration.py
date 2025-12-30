#!/usr/bin/env python3
"""
TaskWarrior on-modify hook: Update totalactivetime from timewarrior.

When a task is stopped (or modified), queries timewarrior for total time
tracked with this task's description and updates the totalactivetime UDA.

This works alongside the standard on-modify.timewarrior hook that handles
starting/stopping timewarrior tracking.

Note: The standard timewarrior hook tags entries with description + project,
so we query by description to find matching entries.
"""

import json
import subprocess
import sys
from datetime import datetime, timezone


def get_timewarrior_duration(description: str) -> int:
    """Get total tracked time for a task by description from timewarrior.

    The standard on-modify.timewarrior hook uses description as a tag,
    so we query timewarrior for entries with that tag.

    Returns duration in seconds.
    """
    if not description:
        return 0

    try:
        # Query timewarrior for entries tagged with this description
        # timew export returns JSON with start/end times
        result = subprocess.run(
            ["timew", "export", description], capture_output=True, text=True, timeout=5
        )

        if result.returncode != 0:
            return 0

        entries = json.loads(result.stdout) if result.stdout.strip() else []

        total_seconds = 0
        for entry in entries:
            if "start" not in entry:
                continue

            # Parse ISO format timestamps (timewarrior uses YYYYMMDDTHHMMSSZ)
            start_str = entry["start"]
            # Handle both formats: with and without Z suffix
            if start_str.endswith("Z"):
                start = datetime.strptime(start_str, "%Y%m%dT%H%M%SZ").replace(
                    tzinfo=timezone.utc
                )
            else:
                start = datetime.strptime(start_str, "%Y%m%dT%H%M%S").replace(
                    tzinfo=timezone.utc
                )

            if "end" in entry:
                end_str = entry["end"]
                if end_str.endswith("Z"):
                    end = datetime.strptime(end_str, "%Y%m%dT%H%M%SZ").replace(
                        tzinfo=timezone.utc
                    )
                else:
                    end = datetime.strptime(end_str, "%Y%m%dT%H%M%S").replace(
                        tzinfo=timezone.utc
                    )
            else:
                # Entry is still running
                end = datetime.now(timezone.utc)

            duration = (end - start).total_seconds()
            total_seconds += max(0, duration)

        return int(total_seconds)

    except Exception:
        return 0


def format_duration_iso(seconds: int) -> str:
    """Format seconds as ISO 8601 duration for taskwarrior.

    Examples:
        3600 -> PT1H
        5400 -> PT1H30M
        90 -> PT1M30S
    """
    if seconds <= 0:
        return "PT0S"

    hours, remainder = divmod(seconds, 3600)
    minutes, secs = divmod(remainder, 60)

    parts = ["PT"]
    if hours:
        parts.append(f"{hours}H")
    if minutes:
        parts.append(f"{minutes}M")
    if secs or (not hours and not minutes):
        parts.append(f"{secs}S")

    return "".join(parts)


def main() -> None:
    # on-modify receives TWO lines: original task, then modified task
    original_json = sys.stdin.readline()
    modified_json = sys.stdin.readline()

    # Parse both
    original = json.loads(original_json)
    modified = json.loads(modified_json)

    # Get task description for timewarrior lookup
    description = modified.get("description", "")

    # Check if task was just stopped (had start, no longer has start)
    was_active = "start" in original
    is_active = "start" in modified
    task_stopped = was_active and not is_active

    # Update duration when task is stopped or completed/deleted
    status = modified.get("status", "pending")
    should_update = task_stopped or status in ("completed", "deleted")

    if should_update and description:
        duration_seconds = get_timewarrior_duration(description)
        if duration_seconds > 0:
            modified["totalactivetime"] = format_duration_iso(duration_seconds)

    # Output the modified task
    print(json.dumps(modified))
    sys.exit(0)


if __name__ == "__main__":
    main()
