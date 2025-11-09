---
allowed-tools: Bash(jj log:*), Bash(jj squash:*), Bash(jj status:*), Bash(cat:*), Read
argument-hint: [base-revision]
description: Squash all todo-created JJ changes into a clean commit history
model: claude-haiku-4-5
---

## Context

- Current status: !`jj status`
- Current commit: !`jj log -r @ --no-graph -T 'concat(change_id.short(), ": ", description)'`
- Todo state file: `~/.config/claude/jj-todo-state.json`

## Your Task

Clean up the JJ changes created by the todo-commit-hook by squashing them appropriately.

**What this does:**

The todo-commit-hook creates individual JJ changes for each todo item. After completing work, you often want to:
1. Squash all the todo changes together into coherent commits
2. Clean up "todo: ..." prefixed descriptions
3. Create a clean, logical commit history

**Workflow:**

1. Read the todo state file to find all todo-created changes:
   ```bash
   cat ~/.config/claude/jj-todo-state.json
   ```

2. Show the current stack including todo changes:
   ```bash
   jj log -r 'all()' --limit 20
   ```

3. **Strategy A: Squash all into base** (simple cleanup)
   - Squash all todo changes back into the base change
   - Update description to reflect completed work
   ```bash
   # For each todo change (from bottom to top)
   jj squash -r <change-id>

   # Update description
   jj describe -m "Completed: <summary of all work>"
   ```

4. **Strategy B: Group by feature** (preserve some structure)
   - Group related todos together
   - Create meaningful commit messages for each group
   ```bash
   # Squash related changes together
   jj squash -r <change-1> --into <change-2>
   ```

5. **Strategy C: Keep granular** (minimal cleanup)
   - Just update descriptions to remove "todo:" prefix
   - Keep the fine-grained commit structure
   ```bash
   # For each change
   jj describe -r <change-id> -m "<improved description>"
   ```

**Recommended approach:**

1. Review the changes made in each todo commit
2. Ask user which strategy they prefer (A, B, or C)
3. Execute the chosen strategy
4. Show the cleaned-up log

**After cleanup:**

```bash
# Show final result
jj log -r 'all()' --limit 10

# Clear the todo state (optional)
rm ~/.config/claude/jj-todo-state.json
```

**Important:**

- Always safe - can undo with `jj undo`
- Consider the logical grouping of changes
- Update commit messages to be meaningful, not just "todo: ..."
- Don't need to rush - can leave todo changes and clean up later

**Example:**

```bash
# Before cleanup:
# - abc123: todo: Create database schema
# - def456: todo: Add API endpoints
# - ghi789: todo: Write tests

# After Strategy A:
# - merged: Add user authentication feature (includes schema, API, tests)

# After Strategy B:
# - abc123: Add user database schema and models
# - def456: Implement authentication API endpoints and tests
```
