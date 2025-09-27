#!/usr/bin/env python3
"""
Very conservative removal - only intervals that are clearly Claude Code automation.
"""
import subprocess
import json
import sys
from datetime import datetime

def is_definitely_claude_automation(interval):
    """Only return True for intervals that are definitely Claude Code automation."""
    tags = set(interval.get('tags', []))
    
    if not tags:
        return False
    
    # Pattern 1: Has claude-code tag
    if any('claude-code' in tag for tag in tags):
        return True
    
    # Pattern 2: Very short devops-only intervals (Claude's quick operations)
    if tags == {'devops'}:
        start = interval.get('start')
        end = interval.get('end')
        if start and end:
            try:
                start_time = datetime.fromisoformat(start.replace('Z', '+00:00'))
                end_time = datetime.fromisoformat(end.replace('Z', '+00:00'))
                duration = (end_time - start_time).total_seconds()
                if duration < 60:  # Less than 1 minute
                    return True
            except:
                pass
    
    # Pattern 3: Only project:sources + review + swift (automated code review)
    if tags == {'project:sources', 'review', 'swift'}:
        return True
    
    # Pattern 4: Only project:view + review + swift (automated file viewing)
    if tags == {'project:view', 'review', 'swift'}:
        return True
    
    # Pattern 5: devops + git combinations (git operations)
    if tags == {'devops', 'git'}:
        return True
    
    # Pattern 6: Only build + devops (build operations)
    if tags == {'build', 'devops'}:
        return True
    
    # Pattern 7: Only research (automated research)
    if tags == {'research'}:
        return True
    
    # Pattern 8: Dependencies + devops (package management)
    if tags == {'dependencies', 'devops'}:
        return True
    
    # Pattern 9: Testing + devops (automated testing)
    if tags == {'devops', 'testing'}:
        return True
    
    return False

def main():
    force = "--force" in sys.argv
    
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
    
    # Find definitely automated intervals
    automated_intervals = []
    for i, interval in enumerate(intervals):
        if is_definitely_claude_automation(interval):
            automated_intervals.append((i + 1, interval))
    
    print(f"Found {len(automated_intervals)} definitely automated intervals")
    
    if not automated_intervals:
        print("No definitely automated intervals found!")
        return
    
    # Show what will be deleted
    print("\nDefinitely automated intervals to delete:")
    for i, (interval_id, interval) in enumerate(automated_intervals[:15]):
        tags = interval.get('tags', [])
        start = interval.get('start', 'unknown')[8:16]  # Just time part
        end = interval.get('end', '')
        if end:
            end = end[8:16]
            duration_info = f"{start}-{end}"
        else:
            duration_info = f"{start} (active)"
        
        print(f"  @{interval_id}: {', '.join(sorted(tags))} - {duration_info}")
    
    if len(automated_intervals) > 15:
        print(f"  ... and {len(automated_intervals) - 15} more")
    
    # Confirm deletion
    if not force:
        response = input(f"\nDelete these {len(automated_intervals)} automated intervals? (yes/no): ")
        if response.lower() != 'yes':
            print("Aborted.")
            return
    else:
        print("\nForce flag detected, proceeding...")
    
    # Stop any active tracking first
    subprocess.run(['timew', 'stop'], capture_output=True)
    
    # Delete intervals in reverse order
    deleted = 0
    for interval_id, interval in reversed(automated_intervals):
        result = subprocess.run(['timew', 'delete', f'@{interval_id}'], 
                              input='yes\n', text=True, capture_output=True)
        if result.returncode == 0:
            deleted += 1
            if deleted % 50 == 0:
                print(f"Deleted {deleted} intervals...")
    
    print(f"\nDeleted {deleted} automated intervals!")

if __name__ == "__main__":
    main()