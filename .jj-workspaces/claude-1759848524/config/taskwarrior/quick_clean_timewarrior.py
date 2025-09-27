#!/usr/bin/env python3
"""
Quick cleanup script to remove claude-code tags from timewarrior data.
"""
import json
import subprocess
import sys

def main():
    print("Exporting timewarrior data...")
    
    # Export all data
    result = subprocess.run(['timew', 'export'], capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error exporting data: {result.stderr}")
        return
    
    if not result.stdout.strip():
        print("No timewarrior data found.")
        return
    
    # Parse JSON data
    try:
        intervals = json.loads(result.stdout)
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON: {e}")
        return
    
    print(f"Found {len(intervals)} intervals")
    
    # Filter out claude-code tags and intervals that are only claude-code
    modified_count = 0
    deleted_count = 0
    
    for interval in intervals[:]:  # Copy list to allow modification
        if 'tags' in interval and interval['tags']:
            original_tags = interval['tags'][:]
            # Remove claude-code tags
            interval['tags'] = [tag for tag in interval['tags'] if 'claude-code' not in tag.lower()]
            
            if len(interval['tags']) != len(original_tags):
                modified_count += 1
            
            # If no tags left, mark for deletion
            if not interval['tags']:
                intervals.remove(interval)
                deleted_count += 1
    
    print(f"Will modify {modified_count} intervals")
    print(f"Will delete {deleted_count} intervals")
    
    if modified_count == 0 and deleted_count == 0:
        print("No changes needed!")
        return
    
    # Clear and reimport
    print("Clearing timewarrior database...")
    subprocess.run(['timew', 'delete', '@1', '@2000'], input='yes\n', text=True)
    
    print("Reimporting cleaned data...")
    clean_json = json.dumps(intervals, indent=2)
    result = subprocess.run(['timew', 'import'], input=clean_json, text=True, capture_output=True)
    
    if result.returncode == 0:
        print("Successfully cleaned timewarrior data!")
        print(f"Modified {modified_count} intervals")
        print(f"Deleted {deleted_count} intervals")
    else:
        print(f"Error importing data: {result.stderr}")

if __name__ == "__main__":
    main()