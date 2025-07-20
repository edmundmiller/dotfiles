#!/usr/bin/env python3
"""
Stop hook for generating development session summaries.
Shows task progress and time tracking summary when Claude Code sessions end.
"""
import json
import sys
import subprocess
from datetime import datetime, timedelta

def get_task_summary():
    """Get a summary of task activity."""
    try:
        # Get tasks modified today
        result = subprocess.run([
            'task', 'export', 'modified.after:today'
        ], capture_output=True, text=True)
        
        if result.returncode != 0:
            return None
        
        tasks = json.loads(result.stdout) if result.stdout.strip() else []
        
        completed_today = []
        modified_today = []
        
        for task in tasks:
            if task.get('status') == 'completed':
                completed_today.append(task)
            else:
                modified_today.append(task)
        
        return {
            'completed': completed_today,
            'modified': modified_today,
            'total_completed': len(completed_today),
            'total_modified': len(modified_today)
        }
    except Exception as e:
        return None

def get_time_summary():
    """Get time tracking summary for today."""
    try:
        # Get today's time summary
        result = subprocess.run([
            'timew', 'summary', ':day'
        ], capture_output=True, text=True)
        
        if result.returncode != 0:
            return None
        
        # Parse the output to extract total time
        lines = result.stdout.split('\n')
        total_line = next((line for line in lines if 'Total' in line), None)
        
        if total_line:
            parts = total_line.split()
            if len(parts) >= 2:
                total_time = parts[-1]
                return {
                    'total_time': total_time,
                    'raw_output': result.stdout
                }
        
        return None
    except Exception as e:
        return None

def get_current_tracking_status():
    """Check if time tracking is currently active."""
    try:
        result = subprocess.run([
            'timew', 'get', 'dom.active'
        ], capture_output=True, text=True)
        
        active = result.stdout.strip() == '1'
        
        if active:
            # Get current tags
            tag_result = subprocess.run([
                'timew', 'get', 'dom.active.tag.1'
            ], capture_output=True, text=True)
            
            current_tag = tag_result.stdout.strip() if tag_result.returncode == 0 else 'untagged'
            return {'active': True, 'current_tag': current_tag}
        
        return {'active': False, 'current_tag': None}
    except Exception as e:
        return {'active': False, 'current_tag': None}

def format_task_summary(task_data):
    """Format task summary for display."""
    if not task_data:
        return "📋 No task data available"
    
    summary = []
    
    if task_data['total_completed'] > 0:
        summary.append(f"✅ Completed {task_data['total_completed']} task(s) today:")
        for task in task_data['completed'][:3]:  # Show first 3
            desc = task.get('description', 'Unknown task')[:50]
            summary.append(f"   • {desc}")
        
        if len(task_data['completed']) > 3:
            summary.append(f"   • ... and {len(task_data['completed']) - 3} more")
    
    if task_data['total_modified'] > 0:
        summary.append(f"📝 Modified {task_data['total_modified']} task(s)")
    
    if not summary:
        summary.append("📋 No tasks completed or modified today")
    
    return '\n'.join(summary)

def format_time_summary(time_data, tracking_status):
    """Format time tracking summary for display."""
    if not time_data:
        return "⏱️  No time tracking data available"
    
    summary = [f"⏱️  Total development time today: {time_data['total_time']}"]
    
    if tracking_status['active']:
        summary.append(f"🔴 Still tracking: {tracking_status['current_tag']}")
        summary.append("   (Run 'timew stop' to stop tracking)")
    else:
        summary.append("⏸️  Time tracking stopped")
    
    return '\n'.join(summary)

def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)
    
    hook_event = input_data.get("hook_event_name", "")
    stop_hook_active = input_data.get("stop_hook_active", False)
    
    # Only run on actual Stop events, not recursive calls
    if hook_event != "Stop" or stop_hook_active:
        sys.exit(0)
    
    print("\n" + "="*50)
    print("📊 DEVELOPMENT SESSION SUMMARY")
    print("="*50)
    
    # Get and display task summary
    task_data = get_task_summary()
    task_summary = format_task_summary(task_data)
    print(f"\n{task_summary}")
    
    # Get and display time summary
    time_data = get_time_summary()
    tracking_status = get_current_tracking_status()
    time_summary = format_time_summary(time_data, tracking_status)
    print(f"\n{time_summary}")
    
    # Show quick stats
    print(f"\n📈 QUICK STATS")
    print(f"Session ended: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    if task_data and time_data:
        completed = task_data['total_completed']
        total_time = time_data['total_time']
        print(f"Productivity: {completed} tasks in {total_time}")
    
    print("="*50)
    
    # Suggest next actions if there are pending tasks
    if task_data and task_data['total_modified'] > 0:
        print("\n💡 TIP: Use '/task-add' to review your pending tasks")
    
    if tracking_status['active']:
        print("💡 TIP: Don't forget to stop time tracking when you're done!")
    
    sys.exit(0)

if __name__ == "__main__":
    main()