#!/usr/bin/env python3
import json
import subprocess
import sys

def get_all_intervals():
    """Get all time intervals from timewarrior"""
    result = subprocess.run(['timew', 'export'], capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error getting intervals: {result.stderr}")
        sys.exit(1)
    return json.loads(result.stdout)

def clean_interval_tags(interval):
    """Remove claude-code and research tags from an interval"""
    if 'tags' not in interval:
        return interval
    
    # Filter out unwanted tags
    original_tags = interval['tags']
    cleaned_tags = [tag for tag in original_tags if tag not in ['claude-code', 'research']]
    
    if cleaned_tags != original_tags:
        interval['tags'] = cleaned_tags
        return interval, True
    return interval, False

def delete_interval(interval_id):
    """Delete a specific interval"""
    cmd = ['timew', 'delete', f'@{interval_id}']
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.returncode == 0

def modify_interval(interval_id, tags):
    """Modify tags for a specific interval"""
    if not tags:
        # If no tags remain, delete the interval
        return delete_interval(interval_id)
    
    # First untag all existing tags
    cmd = ['timew', 'untag', f'@{interval_id}', ':all']
    subprocess.run(cmd, capture_output=True, text=True)
    
    # Then add the cleaned tags
    cmd = ['timew', 'tag', f'@{interval_id}'] + tags
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.returncode == 0

def main():
    print("Fetching all time intervals...")
    intervals = get_all_intervals()
    
    print(f"Found {len(intervals)} intervals")
    
    modified_count = 0
    deleted_count = 0
    
    # Process from newest to oldest to maintain interval IDs
    for i, interval in enumerate(reversed(intervals)):
        interval_id = len(intervals) - i
        
        if 'tags' in interval:
            cleaned_interval, was_modified = clean_interval_tags(interval)
            
            if was_modified:
                if not cleaned_interval['tags']:
                    # No tags left, delete the interval
                    print(f"Deleting interval {interval_id} (all tags were claude-code/research)")
                    if delete_interval(interval_id):
                        deleted_count += 1
                    else:
                        print(f"Failed to delete interval {interval_id}")
                else:
                    # Some tags remain, modify the interval
                    print(f"Modifying interval {interval_id}: {interval['tags']} -> {cleaned_interval['tags']}")
                    if modify_interval(interval_id, cleaned_interval['tags']):
                        modified_count += 1
                    else:
                        print(f"Failed to modify interval {interval_id}")
    
    print(f"\nSummary:")
    print(f"Modified {modified_count} intervals")
    print(f"Deleted {deleted_count} intervals")
    print("\nDone!")

if __name__ == "__main__":
    import sys
    
    # Check if --force flag is provided to skip confirmation
    if "--force" in sys.argv:
        main()
    else:
        # Safety check
        response = input("This will modify your timewarrior data. Make sure you have a backup! Continue? (yes/no): ")
        if response.lower() != 'yes':
            print("Aborted.")
            sys.exit(0)
        
        main()