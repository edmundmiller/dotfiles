# Todo-Commit Workflow

Automatic JJ commit creation and management based on Claude Code's todo system.

## Overview

The todo-commit hook bridges Claude Code's task management with JJ's change-based version control. When Claude Code creates a todo list, the hook automatically:

1. **Creates individual JJ changes** for each todo item
2. **Switches between changes** as work progresses
3. **Tracks the mapping** between todos and commits
4. **Provides cleanup tools** for squashing when done

This gives you a granular, meaningful commit history that maps directly to your task breakdown.

## How It Works

### 1. Initialization Phase

When Claude Code creates a new todo list (via `TodoWrite`), the hook:

```bash
# Starting state: You're on commit @

# Hook creates:
jj new -m "todo: Task 1"  # Creates change abc123
jj new -m "todo: Task 2"  # Creates change def456
jj new -m "todo: Task 3"  # Creates change ghi789

# Returns to base commit @
jj edit <base-change-id>
```

Result: You have a stack of empty changes ready for work.

### 2. Work Phase

As Claude Code works through todos and marks them `in_progress`:

```bash
# Todo 1 becomes in_progress
# Hook automatically runs:
jj edit abc123

# Agent works on Task 1, making edits...
# All changes go into abc123

# Todo 1 completed, Todo 2 becomes in_progress
# Hook automatically runs:
jj edit def456

# Agent works on Task 2...
```

Result: Each task's work is isolated in its own commit.

### 3. Cleanup Phase

After all work is done, use `/todo-squash` or the cleanup helper:

```bash
# Option A: Squash everything together
./hooks/todo-cleanup.py squash-all

# Option B: Just clean up descriptions
./hooks/todo-cleanup.py clean-desc

# Option C: Manual cleanup via /todo-squash command
```

## File Structure

```
config/claude/plugins/jj/
├── hooks/
│   ├── todo-commit-hook.py    # Main hook (PostToolUse: TodoWrite)
│   └── todo-cleanup.py        # Cleanup helper script
├── commands/
│   └── todo-squash.md         # Slash command for cleanup
└── .claude-plugin/
    └── plugin.json            # Hook registration

~/.config/claude/
└── jj-todo-state.json         # State tracking file
```

## State File Format

The hook maintains state in `~/.config/claude/jj-todo-state.json`:

```json
{
  "base_change_id": "abc123def456",
  "session_active": true,
  "todos": [
    {
      "content": "Create database schema",
      "activeForm": "Creating database schema",
      "status": "completed",
      "jj_change_id": "xyz789abc123"
    },
    {
      "content": "Add API endpoints",
      "activeForm": "Adding API endpoints",
      "status": "in_progress",
      "jj_change_id": "def456ghi789"
    }
  ]
}
```

## Commands

### View Status

```bash
./hooks/todo-cleanup.py status
```

Shows:
- Base change ID
- Total todos and their statuses
- Which JJ change corresponds to each todo

### View Commit Stack

```bash
./hooks/todo-cleanup.py show
# or
jj log -r 'all()' --limit 20
```

### Squash All Todos

```bash
./hooks/todo-cleanup.py squash-all
```

Squashes all todo changes back into the base change. You'll want to update the description afterward:

```bash
jj describe -m "Implemented feature X (including schema, API, tests)"
```

### Clean Descriptions

```bash
./hooks/todo-cleanup.py clean-desc
```

Removes the "todo: " prefix from all descriptions, keeping the granular commit structure.

### Interactive Cleanup (Recommended)

```bash
# Use the slash command for guided cleanup
/todo-squash
```

Claude will:
1. Read the state file
2. Show current stack
3. Offer strategies (squash all, group by feature, keep granular)
4. Execute your choice
5. Clean up descriptions

## Example Workflow

### Full Example: Adding Authentication

```bash
# 1. User asks Claude to add authentication
# Claude creates todo list:
#    - Set up database models
#    - Create auth API endpoints
#    - Add JWT token handling
#    - Write tests

# 2. Hook creates JJ changes:
$ jj log
○  todo: Write tests
○  todo: Add JWT token handling
○  todo: Create auth API endpoints
○  todo: Set up database models
@  (empty) Initial work

# 3. Claude works through todos
#    Hook automatically switches between changes
#    Each change gets its corresponding work

$ jj log
○  todo: Write tests                    # 100 insertions (test files)
○  todo: Add JWT token handling         # 50 insertions (jwt.ts)
○  todo: Create auth API endpoints      # 150 insertions (api/)
○  todo: Set up database models         # 75 insertions (models/)
@  (base change)

# 4. Cleanup - Squash all together
$ ./hooks/todo-cleanup.py squash-all
🔄 Squashing 4 todo changes into base...
  [1/4] Squashing: Set up database models
    ✓ Squashed abc123
  [2/4] Squashing: Create auth API endpoints
    ✓ Squashed def456
  [3/4] Squashing: Add JWT token handling
    ✓ Squashed ghi789
  [4/4] Squashing: Write tests
    ✓ Squashed jkl012

✅ All changes squashed!

# 5. Update description
$ jj describe -m "Add JWT authentication with user login/logout"

# 6. Final result
$ jj log
@  Add JWT authentication with user login/logout  # 375 insertions
○  (parent commit)
```

## Configuration

### Enable/Disable the Hook

Edit `.claude-plugin/plugin.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "TodoWrite",
        "hooks": [
          {
            "type": "script",
            "script": "./hooks/todo-commit-hook.py"
          }
        ]
      }
    ]
  }
}
```

To disable: Remove the `TodoWrite` section.

### State File Location

Default: `~/.config/claude/jj-todo-state.json`

To change: Edit `STATE_FILE` in `hooks/todo-commit-hook.py`:

```python
STATE_FILE = Path.home() / ".config" / "claude" / "jj-todo-state.json"
```

## Advanced Usage

### Manual State Inspection

```bash
# View state file
cat ~/.config/claude/jj-todo-state.json | jq

# Find which change you're on
jj log -r @ --no-graph -T change_id

# Find corresponding todo
cat ~/.config/claude/jj-todo-state.json | jq '.todos[] | select(.jj_change_id | startswith("abc123"))'
```

### Partial Squashing

```bash
# Squash just the first two todos together
jj squash -r <change-2> --into <change-1>

# Update description
jj describe -r <change-1> -m "Combined: Task 1 and Task 2"
```

### Cherry-Picking Todo Changes

```bash
# Move a specific todo change to a different parent
jj rebase -s <todo-change-id> -d <new-parent>

# Or duplicate it
jj duplicate <todo-change-id>
```

## Troubleshooting

### Hook Not Running

1. **Check hook registration:**
   ```bash
   cat .claude-plugin/plugin.json | jq '.hooks.PostToolUse[] | select(.matcher == "TodoWrite")'
   ```

2. **Verify script is executable:**
   ```bash
   ls -la hooks/todo-commit-hook.py
   # Should show: -rwxr-xr-x
   ```

3. **Test hook directly:**
   ```bash
   echo '{"tool":{"name":"TodoWrite","params":{"todos":[{"content":"test","status":"pending","activeForm":"testing"}]}}}' | ./hooks/todo-commit-hook.py
   ```

### Changes Not Switching

1. **Check state file:**
   ```bash
   cat ~/.config/claude/jj-todo-state.json | jq '.todos[] | {content, status, jj_change_id}'
   ```

2. **Verify status transitions:**
   - Hook only switches on `pending → in_progress`
   - Won't switch if already in_progress

3. **Manual switch:**
   ```bash
   # Find the change ID from state file
   jj edit <change-id>
   ```

### State File Corruption

```bash
# Reset state (will lose todo-commit mapping)
rm ~/.config/claude/jj-todo-state.json

# Or backup and inspect
cp ~/.config/claude/jj-todo-state.json ~/jj-todo-state.backup
jq . ~/.config/claude/jj-todo-state.json  # Validate JSON
```

### Cleanup Failures

```bash
# If squash-all fails partway through, undo
jj undo

# Check for conflicts
jj log -r 'all()' -T 'concat(change_id.short(), " ", if(conflict, "⚠️ CONFLICT", "✓"))'

# Resolve conflicts manually
jj resolve
```

## Design Philosophy

### Why This Approach?

1. **Granular History**: Each task gets its own commit, making history readable
2. **Automatic Switching**: Agent works in the right context without manual intervention
3. **Flexibility**: Keep granular commits or squash - your choice
4. **Undoability**: Everything is undoable with `jj undo`
5. **Transparency**: State file shows exactly what's happening

### Alternative Approaches Considered

**Approach 1: Single commit with todo comments**
- ❌ Loses granularity
- ❌ Hard to review changes per task
- ✅ Simpler

**Approach 2: Branches per todo**
- ❌ Complex branch management
- ❌ Merge conflicts
- ✅ More traditional workflow

**Approach 3: Description-only tracking**
- ❌ No code isolation
- ❌ Agent has to manually switch
- ✅ Less automation overhead

**Our approach (JJ changes per todo):**
- ✅ Granular, isolated changes
- ✅ Automatic switching
- ✅ Leverages JJ's change model
- ⚠️ Requires cleanup step

## Best Practices

1. **Let it create changes**: Don't manually intervene during the work phase
2. **Review before squashing**: Look at what's in each change
3. **Update descriptions**: Remove "todo: " prefix, make them meaningful
4. **Don't commit state file**: It's in `~/.config`, not your repo
5. **Use jj log frequently**: Understand where you are in the stack
6. **Cleanup when done**: Don't leave todo changes hanging

## Integration with Other JJ Workflows

### With `jj fix`

The `jj fix` PostToolUse hooks still work:

```bash
# After Edit/MultiEdit, formatting runs on current change
# If you're on a todo change, it formats that change
```

### With `/jj:commit` and `/jj:split`

```bash
# If you need to split a todo change:
jj edit <todo-change-id>
/jj:split

# If you need to add a manual commit:
jj new -m "Manual work"
# This won't be tracked by todo system
```

### With SPR (Stacked Pull Requests)

```bash
# After todo work is done and squashed:
# Each meaningful commit can become a PR
jj bookmark create feature-auth-models -r <commit-1>
jj bookmark create feature-auth-api -r <commit-2>

# Submit as stack
git spr submit
```

## Future Enhancements

Possible improvements to consider:

1. **Smart squashing**: Auto-detect related todos and suggest grouping
2. **Conflict detection**: Warn if todos have overlapping file changes
3. **Progress tracking**: Show completion percentage in jj log
4. **Integration with tests**: Run tests per todo change
5. **PR automation**: Auto-create PRs for completed todo groups
6. **Rollback support**: Undo just one todo without affecting others

## Related Documentation

- [JJ Plugin README](./README.md) - Overview of the entire plugin
- [AUTOMATION-ANALYSIS.md](./AUTOMATION-ANALYSIS.md) - Hook architecture analysis
- [commands/squash.md](./commands/squash.md) - General squashing guide
- [Jujutsu Documentation](https://github.com/martinvonz/jj) - JJ concepts

## License

MIT (same as parent plugin)

---

**Version**: 1.0.0
**Last Updated**: 2025-11-09
**Maintainer**: emiller
