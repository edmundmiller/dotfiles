#!/bin/bash
# Fix the active claude-code interval

echo "Stopping current tracking and starting new without claude-code..."

# Get current tags except claude-code
tags=$(timew @1 export | jq -r '.[0].tags | map(select(. != "claude-code")) | join(" ")')

# Stop current (will error but that's ok)
timew stop 2>/dev/null || true

# Start new tracking with cleaned tags
if [ -n "$tags" ]; then
    timew start $tags
    echo "Started new tracking with tags: $tags"
else
    echo "No tags to continue with"
fi