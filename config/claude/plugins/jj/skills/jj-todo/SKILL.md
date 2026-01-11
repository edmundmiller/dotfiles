# JJ-Todo Workflow

You're helping with a system that uses **jj commits as a visual, version-controlled todo list** instead of the traditional TodoWrite tool.

## Core Concept

**The jj commit graph IS your todo list.** Each task is a commit with a status indicator:

- `[TODO]` = Pending task (empty commit, not started)
- `[WIP]` = Work in progress (current @ working commit with changes)
- No prefix = Completed task (regular commit with finished changes)

## How It Works

### Automatic Synchronization

When you use the TodoWrite tool, a PostToolUse hook automatically:
1. Translates your todos into jj commits
2. Creates/updates commit descriptions with status prefixes
3. Maintains a commit stack that mirrors your todo list

**You don't need to do anything special** - just use TodoWrite as normal, and the jj commits are created automatically!

### Manual Todo Management

Users can also manage todos directly with jj commands:

**View todos:**
```bash
/jj-todo:status          # Show the todo stack
jj log -r '::@'          # Standard jj log view
```

**Navigate todos:**
```bash
/jj-todo:next            # Move to next pending task
jj edit <change-id>      # Switch to any task manually
```

**Complete tasks:**
```bash
/jj-todo:done            # Mark current as done, move to next
```

**Create todo stack:**
```bash
/jj-todo:create Task 1 | Task 2 | Task 3
```

## Workflow Patterns

### Pattern 1: TodoWrite + Auto-Sync (Recommended)

You use TodoWrite like normal, and todos automatically become jj commits:

```markdown
1. You call TodoWrite with tasks
2. Hook creates [TODO] commits in stack
3. You mark a task as in_progress
4. Hook updates that commit to [WIP]
5. You complete work and mark completed
6. Hook removes prefix (making it a regular commit)
```

The user can view progress with `jj log` at any time!

### Pattern 2: Pure JJ Commands

Users can bypass TodoWrite entirely:

```bash
# Create todo stack
/jj-todo:create Implement auth | Add tests | Update docs

# Work on first task
# (already on it, marked as [WIP])
# ... make changes ...

# Complete and move to next
/jj-todo:done

# Continue working...
```

### Pattern 3: Hybrid Approach

Mix TodoWrite (for planning) with jj commands (for navigation):

```markdown
1. Use TodoWrite to create task list
2. User runs /jj-todo:status to see graph
3. User runs /jj-todo:next to switch tasks
4. You update TodoWrite to mark completed
```

## Key Advantages

**Visual Todo List:**
- `jj log` shows your todos as a commit graph
- Clear visual hierarchy and status

**Version Controlled:**
- Every todo change is in `jj op log`
- Undo any todo operation with `jj undo`

**Integrated Workflow:**
- Todos and work are in the same commit structure
- Completed commits contain actual changes

**No Context Switching:**
- Don't need external todo tool
- Git graph tools (like lazygit) can visualize todos

## When to Use Each Approach

**Use TodoWrite + Auto-Sync when:**
- You want Claude to track tasks automatically
- Planning complex multi-step work
- Following standard Claude Code workflow

**Use Pure JJ Commands when:**
- User prefers command-line todo management
- Working in tight iteration loop
- Already comfortable with jj

**Use Hybrid when:**
- Planning complex work (TodoWrite)
- User wants to navigate manually (jj commands)
- Best of both worlds

## Important Notes

### Empty Commits are OK

`[TODO]` and `[WIP]` commits can be empty - they're placeholders for planned work. When work is done, the prefix is removed and the commit contains actual changes.

### Stack Structure

Todos are organized as a stack (linear history):
```
@  [WIP] Current task
│
○  [TODO] Next task
│
○  [TODO] Future task
│
○  Completed task with changes
```

### Integration with JJ Workflow

This complements, doesn't replace, jj's commit workflow:
- Still use `jj describe` for commit messages
- Still use `jj squash` to combine commits
- Still use `jj split` to separate concerns
- Todo commits are just regular commits with special prefixes

When done with all todos, you can:
1. Squash related completed commits together
2. Use `jj describe` to write final commit messages
3. The history is already clean (no prefixes on completed work)

### Undoing Todo Operations

Everything is undoable:
```bash
jj undo              # Undo last todo operation
jj op log            # See all todo changes
jj op restore @-     # Restore previous state
```

## Communication with User

When discussing todos, you can mention both perspectives:

"I've updated the todo list - you can see the tasks in the jj commit graph with `/jj-todo:status` or `jj log -r '::@'`"

"Task completed! Use `/jj-todo:done` to move to the next task, or I can update the todo list."

## Examples

### Example 1: Claude Planning Work

```markdown
User: "Add authentication to the app"

Claude: "I'll break this down into tasks:"

*Uses TodoWrite to create:*
1. Design auth flow
2. Implement login endpoint
3. Add JWT validation
4. Write tests

*Hook automatically creates:*
@  [WIP] Design auth flow
│
○  [TODO] Implement login endpoint
│
○  [TODO] Add JWT validation
│
○  [TODO] Write tests

Claude: "I've created a task stack. You can view it with `/jj-todo:status`"
```

### Example 2: User Managing Todos

```markdown
User: "/jj-todo:create Fix bug | Add feature | Refactor"

Claude: *Executes commands, creates stack*

Created 3 tasks:
  • Fix bug (in progress)
  • Add feature (pending)
  • Refactor (pending)

View stack: jj log -r '::@'

User: *works on bug fix*

User: "/jj-todo:done"

Claude: *Marks bug as done, moves to next task*

✅ Completed: Fix bug
🚀 Now working on: Add feature
```

## Summary

The jj-todo system gives you **two ways to manage todos**:

1. **Automatic** - Use TodoWrite normally, hook creates commits
2. **Manual** - Use `/jj-todo:*` commands directly

Both approaches maintain the same commit structure, so users can switch between them freely. The key insight is: **the jj commit graph becomes a visual, version-controlled todo list**.
