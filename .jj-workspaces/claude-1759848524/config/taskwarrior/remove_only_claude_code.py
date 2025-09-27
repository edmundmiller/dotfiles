#!/usr/bin/env python3
"""
Conservative script to ONLY remove intervals with claude-code tag.
"""
import subprocess
import json
import sys

def main():
    print("Exporting timewarrior data...")
    
    # Export all data
    result = subprocess.run(['timew', 'export'], capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error exporting data: {result.stderr}")
        return
    
    try:
        intervals = json.loads(result.stdout)
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON: {e}")
        return
    
    print(f"Found {len(intervals)} total intervals")
    
    # Find intervals with claude-code tag
    claude_intervals = []
    for i, interval in enumerate(intervals):
        tags = interval.get('tags', [])
        if any('claude-code' in tag for tag in tags):
            claude_intervals.append(i + 1)  # timew uses 1-based indexing
    
    print(f"Found {len(claude_intervals)} intervals with claude-code tag")
    
    if not claude_intervals:
        print("No claude-code intervals found!")
        return
    
    # Show what will be deleted
    print("\nIntervals to be deleted:")
    for i in claude_intervals[:10]:
        interval = intervals[i-1]
        tags = interval.get('tags', [])
        start = interval.get('start', 'unknown')[:10]  # Just date
        duration = interval.get('duration', 0)
        mins = duration // 60 if isinstance(duration, (int, float)) else 0
        print(f"  @{i}: {', '.join(tags[:3])}... - {start} ({mins} mins)")
    if len(claude_intervals) > 10:
        print(f"  ... and {len(claude_intervals) - 10} more")
    
    # Delete using untag instead of delete to preserve the intervals
    print(f"\nRemoving claude-code tag from {len(claude_intervals)} intervals...")
    
    removed = 0
    for interval_id in claude_intervals:
        result = subprocess.run(['timew', 'untag', f'@{interval_id}', 'claude-code'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            removed += 1
            if removed % 100 == 0:
                print(f"Processed {removed} intervals...")
    
    print(f"\nSuccessfully removed claude-code tag from {removed} intervals!")

if __name__ == "__main__":
    main()