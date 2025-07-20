#!/usr/bin/env python3
"""
PreToolUse hook for validating and enhancing task creation in files.
Automatically creates Taskwarrior tasks when certain patterns are detected.
"""
import json
import sys
import re
import subprocess
from datetime import datetime

def extract_tasks_from_content(content):
    """Extract TODO/FIXME/HACK comments and their context."""
    tasks = []
    
    # Pattern to match TODO, FIXME, HACK comments
    patterns = [
        r'(?:^|\s)(?:#|//|/\*|\*)\s*(TODO|FIXME|HACK)(?:\s*\((.*?)\))?:\s*(.+?)(?:\*/|$)',
        r'(?:^|\s)(?:#|//)\s*(TODO|FIXME|HACK):\s*(.+?)$',
    ]
    
    for pattern in patterns:
        for match in re.finditer(pattern, content, re.MULTILINE | re.IGNORECASE):
            task_type = match.group(1).upper()
            
            # Handle different capture group positions
            if len(match.groups()) >= 3 and match.group(2):
                assignee = match.group(2)
                description = match.group(3).strip()
            else:
                assignee = None
                description = match.group(2).strip() if len(match.groups()) >= 2 else match.group(1)
            
            tasks.append({
                'type': task_type,
                'assignee': assignee,
                'description': description,
                'priority': 'H' if task_type in ['FIXME', 'HACK'] else 'M'
            })
    
    return tasks

def create_taskwarrior_task(task, file_path):
    """Create a task in Taskwarrior."""
    cmd = ['task', 'add']
    
    # Build task description
    desc = f"[{task['type']}] {task['description']}"
    if task['assignee']:
        desc += f" (@{task['assignee']})"
    
    cmd.append(desc)
    
    # Add tags
    cmd.extend([
        f"+{task['type'].lower()}",
        '+claude-code',
        f"priority:{task['priority']}",
        f"project:code.{file_path.split('/')[-1].split('.')[0]}"
    ])
    
    # Add annotation with file path
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            # Get the task ID from output
            task_id_match = re.search(r'Created task (\d+)', result.stdout)
            if task_id_match:
                task_id = task_id_match.group(1)
                # Add file path as annotation
                subprocess.run([
                    'task', task_id, 'annotate', 
                    f'Source: {file_path}'
                ], capture_output=True)
            return True, result.stdout.strip()
        else:
            return False, result.stderr.strip()
    except Exception as e:
        return False, str(e)

def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)
    
    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})
    
    # Only process Write, Edit, and MultiEdit tools
    if tool_name not in ["Write", "Edit", "MultiEdit"]:
        sys.exit(0)
    
    # Extract file path and content
    file_path = tool_input.get("file_path", "")
    
    if tool_name == "Write":
        content = tool_input.get("content", "")
    elif tool_name == "Edit":
        content = tool_input.get("new_string", "")
    elif tool_name == "MultiEdit":
        # Combine all new_strings from edits
        content = "\n".join([
            edit.get("new_string", "") 
            for edit in tool_input.get("edits", [])
        ])
    
    # Skip if no content or not a code file
    if not content or not file_path:
        sys.exit(0)
    
    # Check if it's a code file
    code_extensions = ['.py', '.js', '.ts', '.jsx', '.tsx', '.java', '.c', '.cpp', 
                      '.cs', '.go', '.rs', '.rb', '.php', '.swift', '.kt', '.scala',
                      '.sh', '.bash', '.zsh', '.yaml', '.yml', '.json', '.xml']
    
    if not any(file_path.endswith(ext) for ext in code_extensions):
        sys.exit(0)
    
    # Extract tasks from content
    tasks = extract_tasks_from_content(content)
    
    if tasks:
        created_tasks = []
        failed_tasks = []
        
        for task in tasks:
            success, message = create_taskwarrior_task(task, file_path)
            if success:
                created_tasks.append(task)
            else:
                failed_tasks.append((task, message))
        
        # Report results
        if created_tasks:
            print(f"✅ Created {len(created_tasks)} Taskwarrior task(s) from {tool_name} operation:")
            for task in created_tasks:
                print(f"  • [{task['type']}] {task['description'][:50]}...")
        
        if failed_tasks:
            print(f"\n⚠️  Failed to create {len(failed_tasks)} task(s):", file=sys.stderr)
            for task, error in failed_tasks:
                print(f"  • {task['description'][:50]}...: {error}", file=sys.stderr)
    
    # Always allow the operation to proceed
    sys.exit(0)

if __name__ == "__main__":
    main()