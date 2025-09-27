#!/usr/bin/env python3
"""
Comprehensive removal of ALL Claude Code automated intervals from timewarrior.
This script removes any interval that appears to be from automated tracking.
"""
import subprocess
import json
import sys
from datetime import datetime

def is_automated_interval(interval):
    """Determine if an interval is from Claude Code automation."""
    tags = set(interval.get('tags', []))
    
    if not tags:
        return False
    
    # Pattern 1: Any interval with claude-code tag
    if any('claude-code' in tag for tag in tags):
        return True
    
    # Pattern 2: Any interval with devops tag
    if 'devops' in tags:
        return True
    
    # Pattern 3: Automated project patterns with review/coding
    automated_projects = {
        'project:sources', 'project:view', 'project:tests', 'project:tc_swiftbridge',
        'project:taskchampion_swift', 'project:taskchampion_swifttests', 
        'project:taskchampion_swift.docc', 'project:emiller'
    }
    
    has_automated_project = any(proj in ' '.join(tags) for proj in automated_projects)
    if has_automated_project:
        # If it has automated project + review/coding/swift/rust, it's automated
        if tags.intersection({'review', 'coding', 'swift', 'rust'}):
            return True
    
    # Pattern 4: Single automated tags
    single_automated_tags = {'research', 'testing', 'dependencies', 'documentation', 'bash'}
    if len(tags) == 1 and tags.intersection(single_automated_tags):
        return True
    
    # Pattern 5: Build operations
    if 'build' in tags:
        return True
    
    # Pattern 6: Git operations  
    if 'git' in tags:
        return True
    
    # Pattern 7: Language-only tags with technical context
    language_tags = {'swift', 'rust', 'python', 'javascript', 'typescript'}
    if tags.intersection(language_tags) and len(tags) <= 3:
        # If it's just language + 1-2 technical tags, likely automated
        technical_tags = {'coding', 'review', 'testing', 'documentation'}
        if tags.intersection(technical_tags):
            return True
    
    return False

def main():
    force = "--force" in sys.argv
    
    print("Exporting all timewarrior data...")
    
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
    
    # Find all automated intervals
    automated_intervals = []
    manual_intervals = []
    
    for i, interval in enumerate(intervals):
        if is_automated_interval(interval):
            automated_intervals.append((i + 1, interval))
        else:
            manual_intervals.append((i + 1, interval))
    
    print(f"Found {len(automated_intervals)} automated intervals to DELETE")
    print(f"Found {len(manual_intervals)} manual intervals to KEEP")
    
    if not automated_intervals:
        print("No automated intervals found!")
        return
    
    # Show samples of what will be deleted vs kept
    print("\n=== AUTOMATED INTERVALS TO DELETE ===")
    for i, (interval_id, interval) in enumerate(automated_intervals[:10]):
        tags = interval.get('tags', [])
        start = interval.get('start', 'unknown')[8:16]  # Time only
        end = interval.get('end', '')
        duration_info = f"{start}-{end[8:16]}" if end else f"{start} (active)"
        print(f"  DELETE @{interval_id}: {', '.join(sorted(tags))} - {duration_info}")
    
    if len(automated_intervals) > 10:
        print(f"  ... and {len(automated_intervals) - 10} more automated intervals")
    
    print("\n=== MANUAL INTERVALS TO KEEP ===")
    for i, (interval_id, interval) in enumerate(manual_intervals[:10]):
        tags = interval.get('tags', [])
        start = interval.get('start', 'unknown')[8:16]
        end = interval.get('end', '')
        duration_info = f"{start}-{end[8:16]}" if end else f"{start} (active)"
        print(f"  KEEP @{interval_id}: {', '.join(sorted(tags))} - {duration_info}")
    
    if len(manual_intervals) > 10:
        print(f"  ... and {len(manual_intervals) - 10} more manual intervals")
    
    # Confirm deletion
    if not force:
        print(f"\nThis will DELETE {len(automated_intervals)} automated intervals.")
        print(f"This will KEEP {len(manual_intervals)} manual intervals.")
        response = input("Continue with deletion? (yes/no): ")
        if response.lower() != 'yes':
            print("Aborted.")
            return
    else:
        print("\nForce flag detected, proceeding with deletion...")
    
    # Stop any active tracking first
    print("Stopping any active tracking...")
    subprocess.run(['timew', 'stop'], capture_output=True)
    
    # Delete automated intervals in reverse order
    print(f"Deleting {len(automated_intervals)} automated intervals...")
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
    
    print(f"\n✅ Successfully deleted {deleted} automated intervals!")
    print(f"✅ Your timewarrior now contains only {len(manual_intervals)} manual entries")
    
    # Final verification
    result = subprocess.run(['timew', 'export'], capture_output=True, text=True)
    if result.returncode == 0:
        remaining = json.loads(result.stdout)
        print(f"✅ Verified: {len(remaining)} intervals remaining in timewarrior")

if __name__ == "__main__":
    main()