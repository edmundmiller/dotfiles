#!/usr/bin/env bash
# Schedule task for today
# Called from taskwarrior-tui with task UUID as argument
# Keybinding: S

set -e

uuid="$1"
if [[ -z "$uuid" ]]; then
    echo "Error: No task UUID provided" >&2
    exit 1
fi

# Extract task info for feedback
desc=$(task rc.verbose=nothing "$uuid" _unique description 2>/dev/null | head -1)
current_scheduled=$(task rc.verbose=nothing "$uuid" _unique scheduled 2>/dev/null | head -1)

# Check if task exists
if [[ -z "$desc" ]]; then
    echo "Error: Task $uuid not found" >&2
    exit 1
fi

# Check if already scheduled for today
today_date=$(date +%Y-%m-%d)
if [[ "$current_scheduled" == "$today_date" ]]; then
    echo "Task already scheduled for today: $desc"
    exit 0
fi

# Schedule the task for today
task rc.bulk=0 rc.confirmation=off "$uuid" modify scheduled:today >/dev/null 2>&1

# Provide feedback
if [[ -n "$current_scheduled" ]]; then
    echo "Rescheduled for today: $desc (was: $current_scheduled)"
else
    echo "Scheduled for today: $desc"
fi
