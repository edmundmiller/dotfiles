# Taskwarrior & Timewarrior Integration for Claude Code

This integration provides automated task management and time tracking for your Claude Code development sessions.

## Features

### 🔗 Automatic Task Creation
- Detects TODO/FIXME/HACK comments in code
- Creates Taskwarrior tasks automatically
- Tags tasks with file type, project, and priority

### ⏱️ Smart Time Tracking
- Automatically starts Timewarrior when coding
- Tags time entries by file type and operation
- Tracks project context and development activities

### 📊 Session Summaries
- Shows completed tasks and time spent
- Provides productivity insights
- Reminds you to stop time tracking

### 💬 Slash Commands
- `/tasks` - View and manage your task list
- `/task-add` - Create new tasks with guidance
- `/task-done` - Mark tasks as completed
- `/timew` - Control time tracking
- `/timew-report` - Generate time reports

## Installation

1. **Copy the configuration to your Claude settings:**
   ```bash
   # For user-wide settings
   cp settings-example.json ~/.claude/settings.json
   
   # For project-specific settings  
   cp settings-example.json .claude/settings.json
   ```

2. **Update file paths in the configuration:**
   Edit the copied settings.json and replace `/Users/emiller/` with your actual home directory path.

3. **Verify Taskwarrior and Timewarrior are installed:**
   ```bash
   task version
   timew --version
   ```

4. **Test the integration:**
   - Create a file with a TODO comment
   - Check if a task was created: `task list +claude-code`
   - Verify time tracking: `timew`

## Hook Behavior

### PreToolUse Hook (task-validator.py)
- **Triggers:** Write, Edit, MultiEdit operations on code files
- **Action:** Scans for TODO/FIXME/HACK comments and creates tasks
- **Output:** Shows created tasks in Claude Code output

### PostToolUse Hook (time-tracker.py)  
- **Triggers:** Successful file operations and bash commands
- **Action:** Starts/updates time tracking with appropriate tags
- **Tags:** file type, operation type, project context

### Stop Hook (session-summary.py)
- **Triggers:** When Claude Code session ends
- **Action:** Shows completed tasks and time summary
- **Output:** Productivity report and next action suggestions

## Configuration Options

### Customizing Task Creation

Edit `task-validator.py` to modify:
- Comment patterns to detect
- Task priority assignment
- Project name extraction
- Tag generation rules

### Customizing Time Tracking

Edit `time-tracker.py` to modify:
- File type mappings
- Operation categorization  
- Tag generation logic
- Tracking conditions

### Adding Slash Commands

Add new commands to the `slash_commands` section in settings.json:
```json
{
  "slash_commands": {
    "my-command": "/path/to/my-command.md"
  }
}
```

## Example Workflow

1. **Start coding session:**
   ```
   > Write some code with TODO comments
   ✅ Created 2 Taskwarrior task(s) from Write operation
   ▶️ Started time tracking: claude-code coding python project:myapp
   ```

2. **Check tasks:**
   ```
   > /tasks
   Shows current task list and project summary
   ```

3. **Complete work:**
   ```
   > /task-done
   Mark tasks as completed with assistance
   ```

4. **End session:**
   ```
   📊 DEVELOPMENT SESSION SUMMARY
   ✅ Completed 3 task(s) today
   ⏱️ Total development time today: 2:30:00
   ```

## Troubleshooting

### Tasks not being created
- Check that Taskwarrior is installed and configured
- Verify the hook file has execute permissions
- Use `claude --debug` to see hook execution details

### Time tracking not starting
- Verify Timewarrior is installed and initialized
- Check that the hook file paths are correct in settings
- Ensure the hook scripts have execute permissions

### Hooks not running
- Verify settings.json syntax is valid
- Check that file paths in settings point to actual files
- Use `/hooks` command in Claude Code to review configuration

## Security Notes

- These hooks execute shell commands automatically
- Review all scripts before installation
- Scripts are designed to be safe but use at your own risk
- Consider testing in a safe environment first

## Dependencies

- **Taskwarrior**: Task management (`brew install task`)
- **Timewarrior**: Time tracking (`brew install timewarrior`)
- **Python 3**: For hook scripts (usually pre-installed)
- **Claude Code**: AI-powered development assistant

## License

Feel free to modify and distribute these scripts as needed for your development workflow.