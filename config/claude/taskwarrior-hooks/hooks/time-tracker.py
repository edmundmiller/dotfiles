#!/usr/bin/env python3
"""
PostToolUse hook for automatic time tracking with Timewarrior.
Tracks development time for different types of file operations.
"""
import json
import sys
import subprocess
import os
from datetime import datetime
from pathlib import Path

# Mapping of file operations to time tracking tags
OPERATION_TAGS = {
    'Write': 'coding',
    'Edit': 'coding',
    'MultiEdit': 'coding',
    'Read': 'review',
    'Bash': 'devops',
    'Task': 'research'
}

# File type to project tag mapping
FILE_TYPE_TAGS = {
    '.py': 'python',
    '.js': 'javascript',
    '.ts': 'typescript',
    '.jsx': 'react',
    '.tsx': 'react',
    '.swift': 'swift',
    '.java': 'java',
    '.c': 'c',
    '.cpp': 'cpp',
    '.go': 'go',
    '.rs': 'rust',
    '.rb': 'ruby',
    '.php': 'php',
    '.sh': 'bash',
    '.yaml': 'config',
    '.yml': 'config',
    '.json': 'config',
    '.md': 'documentation'
}

def get_current_tracking():
    """Check if timewarrior is currently tracking."""
    try:
        result = subprocess.run(['timew', 'get', 'dom.active'], 
                              capture_output=True, text=True)
        return result.stdout.strip() == '1'
    except:
        return False

def start_tracking(tags):
    """Start time tracking with given tags."""
    try:
        cmd = ['timew', 'start'] + tags
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.returncode == 0, result.stdout + result.stderr
    except Exception as e:
        return False, str(e)

def stop_tracking():
    """Stop current time tracking."""
    try:
        result = subprocess.run(['timew', 'stop'], capture_output=True, text=True)
        return result.returncode == 0, result.stdout + result.stderr
    except Exception as e:
        return False, str(e)

def continue_tracking(tags):
    """Continue time tracking with potentially new tags."""
    try:
        # Stop current tracking
        subprocess.run(['timew', 'stop'], capture_output=True)
        
        # Start with new tags
        cmd = ['timew', 'start'] + tags
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.returncode == 0, result.stdout + result.stderr
    except Exception as e:
        return False, str(e)

def get_project_tag(file_path):
    """Extract project tag from file path."""
    if not file_path:
        return None
    
    path = Path(file_path)
    
    # Look for common project indicators
    for parent in path.parents:
        parent_name = parent.name.lower()
        if parent_name in ['src', 'lib', 'app', 'components', 'services']:
            continue
        
        # Use the first meaningful directory name as project
        if parent_name not in ['.', '..', 'home', 'users']:
            return parent_name.replace('-', '_').replace(' ', '_')
    
    return path.stem if path.stem else 'unknown'

def generate_tags(tool_name, tool_input):
    """Generate appropriate tags for time tracking."""
    tags = ['claude-code']
    
    # Add operation tag
    if tool_name in OPERATION_TAGS:
        tags.append(OPERATION_TAGS[tool_name])
    
    # Add file type tag
    file_path = tool_input.get('file_path', '')
    if file_path:
        file_ext = Path(file_path).suffix.lower()
        if file_ext in FILE_TYPE_TAGS:
            tags.append(FILE_TYPE_TAGS[file_ext])
        
        # Add project tag
        project = get_project_tag(file_path)
        if project:
            tags.append(f'project:{project}')
    
    # Special handling for Bash commands
    if tool_name == 'Bash':
        command = tool_input.get('command', '').lower()
        if any(cmd in command for cmd in ['git', 'commit', 'push', 'pull']):
            tags.append('git')
        elif any(cmd in command for cmd in ['npm', 'yarn', 'pip', 'cargo']):
            tags.append('dependencies')
        elif any(cmd in command for cmd in ['test', 'pytest', 'jest']):
            tags.append('testing')
        elif any(cmd in command for cmd in ['build', 'compile', 'make']):
            tags.append('build')
    
    return tags

def should_track_operation(tool_name, tool_input):
    """Determine if this operation should be tracked."""
    # Skip very quick operations
    if tool_name in ['LS', 'Glob']:
        return False
    
    # Skip system/config files
    file_path = tool_input.get('file_path', '')
    if file_path:
        skip_patterns = ['.git/', '.DS_Store', 'node_modules/', '.env', 'settings.json']
        if any(pattern in file_path for pattern in skip_patterns):
            return False
    
    return True

def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)
    
    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})
    tool_response = input_data.get("tool_response", {})
    
    # Only track successful operations
    if tool_response.get("success") is False:
        sys.exit(0)
    
    # Check if we should track this operation
    if not should_track_operation(tool_name, tool_input):
        sys.exit(0)
    
    # Generate tags for this operation
    tags = generate_tags(tool_name, tool_input)
    
    # Check current tracking status
    currently_tracking = get_current_tracking()
    
    if currently_tracking:
        # Continue tracking with updated tags
        success, message = continue_tracking(tags)
        if success:
            print(f"⏱️  Updated time tracking: {' '.join(tags)}")
        else:
            print(f"⚠️  Failed to update time tracking: {message}", file=sys.stderr)
    else:
        # Start new tracking session
        success, message = start_tracking(tags)
        if success:
            print(f"▶️  Started time tracking: {' '.join(tags)}")
        else:
            print(f"⚠️  Failed to start time tracking: {message}", file=sys.stderr)
    
    sys.exit(0)

if __name__ == "__main__":
    main()