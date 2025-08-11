#!/bin/bash
# Bulk remove claude-code tags from timewarrior

echo "Removing claude-code tags from timewarrior intervals..."

# Process in batches of 100
batch_size=100
current=1
total_removed=0

while true; do
    batch_removed=0
    echo "Processing batch starting at @$current..."
    
    for ((i=current; i<current+batch_size; i++)); do
        if timew untag @$i claude-code 2>/dev/null; then
            ((batch_removed++))
            ((total_removed++))
        else
            # If we can't find the interval, we're probably done
            if [ $batch_removed -eq 0 ]; then
                echo "No more intervals found. Done!"
                echo "Total claude-code tags removed: $total_removed"
                exit 0
            fi
            break
        fi
    done
    
    echo "Removed $batch_removed claude-code tags from this batch"
    current=$((current + batch_size))
    
    # Small delay to avoid overwhelming the system
    sleep 0.5
done