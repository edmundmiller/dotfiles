---
allowed-tools: Bash(jj log:*), Bash(jj diff:*), Bash(jj status:*), Bash(jj squash:*)
argument-hint: [revision]
description: Merge commits in the stack
model: claude-haiku-4-5
---

## Context

- Current status: !`jj status`
- Current commit: !`jj log -r @ --no-graph -T 'concat(change_id.short(), ": ", description)'`
- Parent commit: !`jj log -r @- --no-graph -T 'concat(change_id.short(), ": ", description)'`
- Recent stack: !`jj log -r 'ancestors(@, 5)' -T 'concat(change_id.short(), ": ", description)' --no-graph`

## Your Task

Merge commits in the jujutsu stack.

**Usage Modes:**

1. **Default (no argument):** Merge current commit (@) into its parent (@-)

   ```bash
   jj squash
   ```

   This moves all changes from @ into @-, then abandons @.

2. **With revision:** Merge a specific revision into its parent
   ```bash
   jj squash -r <revision>
   ```
   Useful for cleaning up a specific commit in the stack.

**When to use:**

- Multiple WIP commits for the same feature
- Cleaning up incremental work before sharing
- Combining related changes into a single commit
- Fixing typos or small changes that belong in the parent

**Workflow:**

1. Explain what will be merged (which commits, what changes)
2. Execute the squash operation
3. Show the result with `jj log` and confirm the changes

**Important:**

- Squashing is safe - you can undo with `jj undo`
- Use `jj squash -i` for interactive mode to select specific changes
- Consider if you should update the description after squashing

**Example scenarios:**

**Scenario 1: Merge current WIP into parent**

```bash
# Before: @ = "WIP: fix tests", @- = "Add login feature"
jj squash
# After: @ = "Add login feature" (now includes test fixes)
```

**Scenario 2: Merge specific revision**

```bash
# Merge revision abc123 into its parent
jj squash -r abc123
```

**Scenario 3: Interactive squash**

```bash
# Choose which changes to move
jj squash -i
```

Show result: !`jj log -r 'ancestors(@, 3)' -T 'concat(change_id.short(), ": ", description)' --no-graph`
