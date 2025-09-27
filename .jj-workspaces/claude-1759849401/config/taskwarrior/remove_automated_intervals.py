#!/usr/bin/env python3
"""
Remove all timewarrior intervals that appear to be from automated Claude Code tracking.
Based on the patterns seen in today's data.
"""
import subprocess
import json
import sys
from datetime import datetime

# Automated tags that Claude Code was using
AUTOMATED_TAGS = {
    'devops', 'git', 'build', 'coding', 'review', 'research', 'testing', 
    'dependencies', 'documentation', 'bash', 'claude-code'
}

# Automated project patterns
AUTOMATED_PROJECTS = {
    'project:sources', 'project:view', 'project:tests', 'project:tc_swiftbridge',
    'project:taskchampion_swift', 'project:taskchampion_swifttests', 
    'project:taskchampion_swift.docc', 'project:emiller'
}

def is_automated_interval(interval):
    """Determine if an interval appears to be from automated tracking."""
    tags = set(interval.get('tags', []))
    
    if not tags:
        return False
    
    # If it has claude-code, definitely automated
    if any('claude-code' in tag for tag in tags):
        return True
    
    # Check for automated patterns
    automated_tag_count = len(tags.intersection(AUTOMATED_TAGS))
    automated_project_count = len(tags.intersection(AUTOMATED_PROJECTS))
    
    # Pattern 1: Multiple automated tags
    if automated_tag_count >= 2:
        return True
    
    # Pattern 2: Single automated tag with automated project
    if automated_tag_count >= 1 and automated_project_count >= 1:
        return True
    
    # Pattern 3: Just automated projects with language tags (swift, rust, etc.)
    if automated_project_count >= 1:
        language_tags = {'swift', 'rust', 'python', 'javascript', 'typescript'}
        if tags.intersection(language_tags):
            return True
    
    # Pattern 4: Very short intervals with devops/git (< 5 minutes)
    if tags.intersection({'devops', 'git', 'build'}):
        start = interval.get('start')
        end = interval.get('end')
        if start and end:
            try:
                start_time = datetime.fromisoformat(start.replace('Z', '+00:00'))
                end_time = datetime.fromisoformat(end.replace('Z', '+00:00'))
                duration = (end_time - start_time).total_seconds()
                if duration < 300:  # Less than 5 minutes
                    return True
            except:
                pass
    
    # Pattern 5: Single automated tags without meaningful context
    single_automated = {'devops', 'research', 'testing', 'dependencies', 'documentation'}
    if len(tags) == 1 and tags.intersection(single_automated):
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
    
    # Find automated intervals
    automated_intervals = []
    for i, interval in enumerate(intervals):
        if is_automated_interval(interval):
            automated_intervals.append((i + 1, interval))  # timew uses 1-based indexing
    
    print(f"Found {len(automated_intervals)} automated intervals to delete")
    
    if not automated_intervals:
        print("No automated intervals found!")
        return
    
    # Show sample of what will be deleted
    print("\nSample intervals to be deleted:")
    for i, (interval_id, interval) in enumerate(automated_intervals[:10]):
        tags = interval.get('tags', [])
        start = interval.get('start', 'unknown')[:10]  # Just date
        end = interval.get('end', '')
        if end:
            end = end[:10]
            date_range = f"{start} to {end}" if start != end else start
        else:
            date_range = f"{start} (active)"
        
        print(f"  @{interval_id}: {', '.join(tags[:4])}{'...' if len(tags) > 4 else ''} - {date_range}")
    
    if len(automated_intervals) > 10:
        print(f"  ... and {len(automated_intervals) - 10} more")
    
    # Confirm deletion
    if not force:
        print(f"\nThis will DELETE {len(automated_intervals)} intervals completely.")
        print("These appear to be automated tracking from Claude Code.")
        response = input("Continue? (yes/no): ")
        if response.lower() != 'yes':
            print("Aborted.")
            return
    else:
        print("\nForce flag detected, proceeding with deletion...")
    
    # Stop any active tracking first
    subprocess.run(['timew', 'stop'], capture_output=True)
    
    # Delete intervals in reverse order to maintain ID consistency
    deleted = 0
    for interval_id, interval in reversed(automated_intervals):
        result = subprocess.run(['timew', 'delete', f'@{interval_id}'], 
                              input='yes\n', text=True, capture_output=True)
        if result.returncode == 0:
            deleted += 1
            if deleted % 100 == 0:
                print(f"Deleted {deleted} intervals...")
        else:
            print(f"Failed to delete @{interval_id}: {result.stderr}")
    
    print(f"\nSuccessfully deleted {deleted} automated intervals!")
    print("Your timewarrior now contains only your manual time tracking entries.")

if __name__ == "__main__":
    main()