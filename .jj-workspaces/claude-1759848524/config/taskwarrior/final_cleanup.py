#!/usr/bin/env python3
"""
Final cleanup approach - systematically delete all intervals
"""
import subprocess
import json

def delete_all_intervals():
    """Delete all intervals one by one"""
    deleted_count = 0
    
    while True:
        # Get current intervals
        result = subprocess.run(['timew', 'export'], capture_output=True, text=True)
        if result.returncode != 0:
            print("Error getting intervals")
            break
            
        try:
            intervals = json.loads(result.stdout)
        except:
            intervals = []
            
        if not intervals:
            print("No more intervals to delete!")
            break
            
        print(f"Found {len(intervals)} intervals remaining...")
        
        # Try to delete the first interval
        result = subprocess.run(['timew', 'delete', '@1'], 
                              input='yes\n', text=True, capture_output=True)
        
        if result.returncode == 0:
            deleted_count += 1
            print(f"Deleted interval @1 (total deleted: {deleted_count})")
        else:
            print(f"Failed to delete @1: {result.stderr}")
            # If we can't delete @1, try cancelling and stopping everything
            subprocess.run(['timew', 'cancel'], capture_output=True)
            subprocess.run(['timew', 'stop'], capture_output=True)
            
            # Try again
            result = subprocess.run(['timew', 'delete', '@1'], 
                                  input='yes\n', text=True, capture_output=True)
            if result.returncode == 0:
                deleted_count += 1
                print(f"Deleted interval @1 after cancel/stop (total deleted: {deleted_count})")
            else:
                print("Still can't delete. Breaking out of loop.")
                break
    
    return deleted_count

if __name__ == "__main__":
    print("Starting final cleanup of all timewarrior intervals...")
    
    # Stop any active tracking
    subprocess.run(['timew', 'stop'], capture_output=True)
    subprocess.run(['timew', 'cancel'], capture_output=True)
    
    deleted = delete_all_intervals()
    print(f"\nFinal cleanup complete! Deleted {deleted} total intervals.")
    
    # Verify
    result = subprocess.run(['timew', 'export'], capture_output=True, text=True)
    if result.returncode == 0:
        try:
            remaining = json.loads(result.stdout)
            print(f"Verification: {len(remaining)} intervals remaining in timewarrior")
        except:
            print("Verification: timewarrior database appears empty")
    else:
        print("Verification: could not check remaining intervals")