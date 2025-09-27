#!/usr/bin/env python3
"""
Remove all timewarrior intervals that appear to be from Claude Code automation.
These are intervals with certain tag combinations that indicate automated tracking.
"""
import subprocess
import json

# Tags that indicate Claude Code automated tracking
CLAUDE_TAGS = [
    'claude-code',
    'devops',
    'git', 
    'review',
    'coding',
    'build',
    'research',
    'dependencies',
    'testing',
    'documentation'
]

# Project patterns that indicate Claude Code activity
CLAUDE_PROJECTS = [
    'project:sources',
    'project:view',
    'project:tests',
    'project:tc_swiftbridge',
    'project:taskchampion_swift'
]

def should_delete_interval(interval):
    """Determine if an interval should be deleted based on its tags."""
    tags = interval.get('tags', [])
    if not tags:
        return False
    
    # Check if it has claude-code tag
    if any('claude-code' in tag for tag in tags):
        return True
    
    # Check for automated patterns - multiple technical tags together
    tag_str = ' '.join(tags).lower()
    
    # Pattern 1: devops-only intervals (very short durations)
    if tags == ['devops']:
        return True
    
    # Pattern 2: git + devops
    if 'devops' in tags and 'git' in tags and len(tags) == 2:
        return True
    
    # Pattern 3: review + project:sources/view + swift (automated code review)
    if ('review' in tags and 
        any(proj in tag_str for proj in ['project:sources', 'project:view']) and
        'swift' in tags):
        return True
    
    # Pattern 4: coding + project + language (automated coding)
    if ('coding' in tags and 
        any(proj in tag_str for proj in CLAUDE_PROJECTS)):
        return True
    
    # Pattern 5: build/dependencies/testing + devops
    if 'devops' in tags and any(tag in tags for tag in ['build', 'dependencies', 'testing']):
        return True
    
    # Pattern 6: research-only (automated research)
    if tags == ['research']:
        return True
        
    return False

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
    
    # Find intervals to delete
    intervals_to_delete = []
    for i, interval in enumerate(intervals):
        if should_delete_interval(interval):
            intervals_to_delete.append(i + 1)  # timew uses 1-based indexing
    
    print(f"Found {len(intervals_to_delete)} intervals to delete")
    
    if not intervals_to_delete:
        print("No Claude Code intervals found!")
        return
    
    # Show sample of what will be deleted
    print("\nSample of intervals to be deleted:")
    for i in intervals_to_delete[:5]:
        interval = intervals[i-1]
        tags = interval.get('tags', [])
        start = interval.get('start', 'unknown')
        print(f"  @{i}: {', '.join(tags)} - started {start}")
    if len(intervals_to_delete) > 5:
        print(f"  ... and {len(intervals_to_delete) - 5} more")
    
    # Confirm
    import sys
    if "--force" in sys.argv:
        print("\nForce flag detected, proceeding with deletion...")
    else:
        response = input("\nDelete these intervals? (yes/no): ")
        if response.lower() != 'yes':
            print("Aborted.")
            return
    
    # Delete intervals in reverse order to maintain ID consistency
    deleted = 0
    for interval_id in reversed(intervals_to_delete):
        result = subprocess.run(['timew', 'delete', f'@{interval_id}'], 
                              input='yes\n', text=True, capture_output=True)
        if result.returncode == 0:
            deleted += 1
            if deleted % 100 == 0:
                print(f"Deleted {deleted} intervals...")
    
    print(f"\nSuccessfully deleted {deleted} Claude Code intervals!")

if __name__ == "__main__":
    main()