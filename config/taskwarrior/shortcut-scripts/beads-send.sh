#!/usr/bin/env bash
# Send task to beads - creates a bead in a try workspace
# Called from taskwarrior-tui with task UUID as argument
# Keybinding: b

set -e

uuid="$1"
if [[ -z "$uuid" ]]; then
    echo "Error: No task UUID provided" >&2
    exit 1
fi

# Extract task info
desc=$(task rc.verbose=nothing "$uuid" _unique description 2>/dev/null | head -1)
project=$(task rc.verbose=nothing "$uuid" _unique project 2>/dev/null | head -1)

# Smart project → path inference
# Convert dots to slashes: nf-core.modules → nf-core/modules
inferred_path=""
if [[ -n "$project" ]]; then
    project_as_path="${project//.//}"
    if [[ -d "$HOME/src/$project_as_path" ]]; then
        inferred_path="$HOME/src/$project_as_path"
    fi
fi

# Use inferred path, project name, or description words as try filter
if [[ -n "$inferred_path" ]]; then
    filter="$(basename "$inferred_path")"
elif [[ -n "$project" ]]; then
    filter="$project"
else
    filter="$(echo "$desc" | cut -d' ' -f1-3)"
fi

# Run try interactively and capture the output
# try exec outputs shell commands, we extract the path from 'cd' command
try_output=$(try exec "$filter" 2>/dev/tty)

# Extract path from try output (looks for "cd '/path/to/dir'" pattern)
selected_path=$(echo "$try_output" | grep "^[[:space:]]*cd " | head -1 | sed "s/^[[:space:]]*cd '\\(.*\\)'$/\\1/")

if [[ -z "$selected_path" ]]; then
    echo "No workspace selected" >&2
    exit 1
fi

# Check if repo has beads enabled
if [[ ! -d "$selected_path/.beads" ]]; then
    echo "Error: $selected_path doesn't have beads initialized" >&2
    echo "Run 'bd init' in that directory first" >&2
    exit 1
fi

# TODO: Prompt for type (task/bug/feature), default to task for now
bead_type="task"

# TODO: If task has +bw tag, link to external ref instead of creating new bead

# Create bead in the selected repo
bead_output=$(bd new --repo "$selected_path" --title "$desc" --type "$bead_type" --external-ref "tw-$uuid" --json 2>&1)
bead_id=$(echo "$bead_output" | jq -r '.id // empty')

if [[ -z "$bead_id" ]]; then
    echo "Failed to create bead: $bead_output" >&2
    exit 1
fi

# Annotate task with bead link
task "$uuid" annotate "bead:$bead_id in $(basename "$selected_path")"

# Set bead UDA on task
task rc.bulk=0 rc.confirmation=off "$uuid" modify bead:"$bead_id"

echo "Created $bead_id and linked to task"
