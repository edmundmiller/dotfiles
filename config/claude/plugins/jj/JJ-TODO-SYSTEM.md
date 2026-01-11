# JJ-Todo System

**Use jj commits as a visual, version-controlled todo list**

Instead of using Claude's traditional TodoWrite tool, this system translates todos into jj commits, making your commit graph the todo list visualization.

## Quick Start

The system works automatically when Claude uses TodoWrite. No special commands needed - just work normally and your todos become jj commits!

### View Your Todos

```bash
jj log -r '::@'           # See todo stack in commit graph
/jj-todo:status           # Get formatted todo status
```

### Navigate Todos

```bash
/jj-todo:next            # Move to next pending task
/jj-todo:done            # Complete current, move to next
jj edit <change-id>      # Switch to any task manually
```

### Create Todo Stack

```bash
/jj-todo:create Design API | Implement handlers | Write tests
```

## How It Works

### Status Mapping

Each todo status maps to a commit description pattern:

| TodoWrite Status | JJ Commit Description | Meaning |
|-----------------|----------------------|---------|
| `pending` | `[TODO] Task name` | Empty commit, not started |
| `in_progress` | `[WIP] Task name` | Current working commit |
| `completed` | `Task name` | Regular commit with changes (no prefix) |

### Automatic Synchronization

A PostToolUse hook intercepts TodoWrite calls and:

1. **Creates commits** for new todos as `[TODO]` commits
2. **Updates descriptions** when status changes (`[TODO]` → `[WIP]` → no prefix)
3. **Maintains stack** structure in jj commit graph
4. **Removes prefixes** when tasks are completed

### Example Workflow

```markdown
# Claude creates tasks
Claude uses TodoWrite:
- Design authentication flow
- Implement login endpoint
- Write tests

# Hook creates jj commits:
@  [WIP] Design authentication flow
│
○  [TODO] Implement login endpoint
│
○  [TODO] Write tests

# You work on first task...
# Claude marks it completed via TodoWrite

# Hook updates commit (removes [WIP] prefix):
@  Design authentication flow
│
○  [TODO] Implement login endpoint
│
○  [TODO] Write tests

# Move to next task
/jj-todo:next

# Now working on:
@  [WIP] Implement login endpoint
│
○  Design authentication flow
│
○  [TODO] Write tests
```

## Commands

### `/jj-todo:status`

Shows current todo stack with statistics.

```bash
/jj-todo:status
```

**Output:**
```
Current Todo Stack:

  @  [WIP] Implement login endpoint
  │
  ○  [TODO] Write tests
  │
  ○  Design authentication flow

Status:
  • Total: 3 tasks
  • In Progress: 1
  • Pending: 1
  • Completed: 1
```

### `/jj-todo:next`

Switch to next pending `[TODO]` task and mark it as `[WIP]`.

```bash
/jj-todo:next
```

Automatically:
- Finds next `[TODO]` commit
- Uses `jj edit` to switch to it
- Updates description to `[WIP]`
- Reports status to you

### `/jj-todo:done`

Mark current `[WIP]` task as completed (removes prefix) and move to next.

```bash
/jj-todo:done
```

Automatically:
- Removes `[WIP]` prefix from current commit
- Creates new working commit
- Switches to next `[TODO]` if available
- Updates that task to `[WIP]`

### `/jj-todo:create <tasks>`

Create a todo stack from a list of tasks.

```bash
/jj-todo:create Task 1 | Task 2 | Task 3
```

Creates empty commits in stack, oldest at bottom, newest at top. First task automatically marked `[WIP]`.

## Advantages

### Visual Todo List

Your commit graph **is** your todo visualization. Use any jj log viewer:

```bash
jj log -r '::@'                    # Standard log view
jj log --template '...'            # Custom formatting
lazygit                            # Visual TUI
```

### Version Controlled

Every todo operation is in `jj op log`:

```bash
jj op log                # See all todo changes
jj undo                  # Undo last todo operation
jj op restore @-         # Restore previous state
```

### Integrated Workflow

Todos and work live in the same structure:
- No separate todo app
- Completed commits contain actual changes
- Natural flow from planning → implementation → completion

### Undoable

Everything is reversible:
- Undo todo creation
- Undo status changes
- Restore any previous state
- Safety net for experimentation

## Integration with JJ Workflow

### Compatible with Standard JJ Operations

Todo commits are regular jj commits, so all operations work:

```bash
jj describe             # Edit commit messages
jj squash               # Combine commits
jj split                # Separate concerns
jj new                  # Create new commits
jj edit                 # Switch commits
```

### Cleanup After Completion

When all todos are done:

```bash
# Squash related work together
jj squash -r <completed-task-1> -r <completed-task-2>

# Edit final commit messages
jj describe -m "feature: add authentication system"

# Already clean - no prefixes on completed work!
```

### Working with Empty Commits

`[TODO]` and `[WIP]` commits can be empty - they're placeholders for planned work. When work is completed, the commit contains actual changes and the prefix is removed.

JJ handles empty commits gracefully, and you can always squash them away later if desired.

## Two Workflows

### 1. Automatic (Recommended)

Claude uses TodoWrite normally, hook creates commits automatically:

```markdown
1. Claude receives task
2. Claude uses TodoWrite to plan
3. Hook creates jj commits
4. Claude works and updates TodoWrite
5. Hook syncs changes to commits
6. You see progress in `jj log`
```

**Best for:** Standard Claude Code workflow, complex planning

### 2. Manual Commands

You use `/jj-todo:*` commands directly:

```bash
/jj-todo:create Implement auth | Add tests | Update docs
# Work on first task...
/jj-todo:done
# Work on second task...
/jj-todo:done
```

**Best for:** Quick iteration, command-line preference

### 3. Hybrid

Mix both approaches:
- Use TodoWrite for planning
- Use `/jj-todo:*` for navigation
- Best of both worlds

## Examples

### Example 1: Feature Development

```bash
# Claude receives request: "Add user authentication"

# Claude uses TodoWrite to break down work:
# 1. Design auth flow
# 2. Implement JWT generation
# 3. Add middleware
# 4. Write tests

# Hook automatically creates:
@  [WIP] Design auth flow
│
○  [TODO] Implement JWT generation
│
○  [TODO] Add middleware
│
○  [TODO] Write tests

# Claude works on design, marks complete
# Hook updates:
@  Design auth flow  (no prefix = completed!)
│
○  [TODO] Implement JWT generation
│
○  [TODO] Add middleware
│
○  [TODO] Write tests

# View progress:
$ jj log -r '::@'
# Shows visual todo list with completed work
```

### Example 2: Manual Todo Management

```bash
# Create todo stack
$ /jj-todo:create Fix login bug | Add validation | Update tests

Created 3 tasks:
  • Fix login bug (in progress)
  • Add validation (pending)
  • Update tests (pending)

# Work on bug fix...
# (make changes to code)

# Complete and move to next
$ /jj-todo:done

✅ Completed: Fix login bug
🚀 Now working on: Add validation

# Continue working...
```

### Example 3: Viewing Progress

```bash
# Check todo status
$ /jj-todo:status

Current Todo Stack:

  @  [WIP] Add validation
  │
  ○  [TODO] Update tests
  │
  ○  Fix login bug

Status:
  • Total: 3 tasks
  • In Progress: 1
  • Pending: 1
  • Completed: 1 (no prefix)

# View in standard jj log
$ jj log -r '::@'
# Shows same structure with full commit details
```

## Configuration

The hook is registered in `.claude-plugin/plugin.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "TodoWrite",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/config/claude/plugins/jj/hooks/todo-to-commit.py",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

The hook:
- Runs after every TodoWrite call
- Has 30-second timeout
- Fails open (continues on errors)
- Uses project-relative path

## Troubleshooting

### Hook not running

**Check plugin is active:**
```bash
# Verify .claude-plugin/plugin.json exists in jj plugin directory
ls config/claude/plugins/jj/.claude-plugin/plugin.json
```

**Check hook is executable:**
```bash
ls -l config/claude/plugins/jj/hooks/todo-to-commit.py
# Should show -rwxr-xr-x
chmod +x config/claude/plugins/jj/hooks/todo-to-commit.py
```

### Commits not created

**Ensure you're in a jj repo:**
```bash
jj status
# If not a jj repo: jj git init --colocate
```

**Check hook output:**
Hook errors appear in Claude Code output. Look for messages starting with "📋 **Todo commits updated:**"

### Duplicate todos

If you see duplicate commits, the hook may have created them before matching by content. Use:

```bash
jj log -r '::@'  # Review commits
jj abandon <change-id>  # Remove duplicates
```

### Wrong commit order

Todos are inserted in the order received. If order is wrong:

```bash
jj rebase -r <commit> -d <destination>  # Reorder manually
```

## Technical Details

### Hook Implementation

**Language:** Python (using uv for dependencies)

**Input:** JSON via stdin containing:
- `tool_name`: Should be "TodoWrite"
- `tool_input.todos`: Array of todo objects

**Output:** JSON via stdout:
- `continue`: Always `true` (fail open)
- `additionalContext`: Status message if commits created/updated

**Behavior:**
1. Check if tool is TodoWrite (pass through if not)
2. Extract todos array (pass through if empty)
3. Get existing todo commits from jj (`::@` range)
4. For each todo:
   - Check if commit exists for this content
   - Create new commit or update existing
   - Set description based on status
5. Mark removed todos as completed
6. Return summary message

### Status Transitions

The hook handles all status transitions:

- `pending` → `in_progress`: `[TODO] X` → `[WIP] X`
- `in_progress` → `completed`: `[WIP] X` → `X`
- `pending` → `completed`: `[TODO] X` → `X`
- Removed from list → `completed`: `[TODO]/[WIP] X` → `X`

### JJ Commands Used

The hook uses these jj commands:

```bash
jj log -r '::@' --no-graph -T 'change_id ++ "\t" ++ description'
# Get commits in current stack

jj describe -r <change-id> -m "<new description>"
# Update commit description

jj new -A @ -m "<description>"
# Create new commit before current @
```

### Error Handling

The hook fails open on all errors:
- Missing jj command
- Invalid jj repository
- Malformed input
- Command failures

This ensures Claude Code continues working even if todo→commit sync fails.

## Testing

Tests are in `hooks/jj-hooks.test.mjs`:

```bash
cd config/claude/plugins/jj
bun test hooks/jj-hooks.test.mjs
```

**Test coverage:**
- Non-TodoWrite tools (pass through)
- Empty todos (pass through)
- Single/multiple todos
- Status transitions
- Error handling
- Edge cases (special characters, long content, newlines)

## Future Enhancements

Possible improvements:

1. **Priority support:** Map todo priority to commit markers
2. **Tags:** Use jj bookmarks for todo categories
3. **Dependencies:** Use parent/child commit relationships
4. **Time tracking:** Store start/end times in commit metadata
5. **Subtasks:** Nested commits for subtasks
6. **Filters:** Advanced jj log templates for todo views

## Philosophy

The jj-todo system embraces jj's philosophy:

- **Everything is a commit** - todos are commits
- **Everything is undoable** - all todo ops in operation log
- **Visual representation** - commit graph shows structure
- **Simple operations** - regular jj commands work
- **Version controlled** - todo history preserved

This aligns perfectly with jj's model while giving Claude Code users a native todo management experience.

## See Also

- [JJ Todo Skill](./skills/jj-todo/SKILL.md) - Claude's guide to using the system
- [Todo Commands](./commands/todo-*.md) - Command reference
- [JJ Workflow Plugin](./README.md) - Main plugin documentation
- [Hooks Guide](https://code.claude.com/docs/en/hooks-guide.md) - Claude Code hooks
