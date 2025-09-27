#!/usr/bin/env python3
"""
Simple script to remove claude-code tags from existing timewarrior intervals.
Uses the retag command to modify existing intervals.
"""
import subprocess
import json
import re

def main():
    print("Finding intervals with claude-code tags...")
    
    # Get all intervals with claude-code
    result = subprocess.run(['timew', 'export'], capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error exporting data: {result.stderr}")
        return
    
    try:
        intervals = json.loads(result.stdout)
    except json.JSONDecodeError:
        print("No data or invalid JSON")
        return
    
    # Find intervals with claude-code tags
    claude_intervals = []
    for i, interval in enumerate(intervals):
        if 'tags' in interval and interval['tags']:
            claude_tags = [tag for tag in interval['tags'] if 'claude-code' in tag.lower()]
            if claude_tags:
                claude_intervals.append((i + 1, claude_tags, interval.get('tags', [])))
    
    print(f"Found {len(claude_intervals)} intervals with claude-code tags")
    
    if not claude_intervals:
        print("No claude-code tags found!")
        return
    
    # Remove claude-code tags using untag command
    for interval_id, claude_tags, all_tags in claude_intervals:
        print(f"Removing claude-code tags from interval @{interval_id}")
        
        for tag in claude_tags:
            cmd = ['timew', 'untag', f'@{interval_id}', tag]
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode != 0:
                print(f"Warning: Failed to remove tag '{tag}' from @{interval_id}: {result.stderr}")
    
    print("Done removing claude-code tags!")

if __name__ == "__main__":
    main()