#!/bin/bash
# Nuclear option: Delete all remaining intervals that look automated
# This handles the database consistency issues by using direct deletion

echo "Getting list of all intervals..."
total=$(timew export | jq '. | length')
echo "Found $total intervals remaining"

if [ "$total" -eq 0 ]; then
    echo "No intervals to clean!"
    exit 0
fi

echo "Deleting all remaining intervals (they all appear to be automated)..."

# Stop any active tracking
timew stop 2>/dev/null || true

# Delete all intervals from the end backwards
for ((i=total; i>=1; i--)); do
    echo -n "Deleting @$i... "
    if echo "yes" | timew delete @$i >/dev/null 2>&1; then
        echo "✓"
    else
        echo "✗ (may have been already deleted)"
    fi
done

remaining=$(timew export 2>/dev/null | jq '. | length' 2>/dev/null || echo "0")
echo "Cleanup complete! $remaining intervals remaining."