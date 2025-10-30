---
allowed-tools: Bash(jj workspace:*), Bash(jj log:*)
description: Remove empty or stale jj workspaces
model: claude-haiku-4-5
---

## Context

- Available workspaces: !`jj workspace list`
- Current workspace: !`jj workspace list | grep '*'`

## Your Task

Clean up empty or stale jj workspaces.

**What are jj workspaces?**

Jujutsu workspaces allow you to have multiple working copies of your repository simultaneously. Each workspace can work on different revisions independently.

**When to use cleanup:**

- After finishing work in a temporary workspace
- When you have orphaned workspaces from interrupted work
- To reclaim disk space from unused workspaces
- Regular maintenance to keep workspace list clean

**Steps:**

1. **List all workspaces:**

   ```bash
   jj workspace list
   ```

2. **Check each workspace status:**
   For each workspace (except the current one), check if it's empty or stale:

   ```bash
   jj log -r <workspace-name>@ --no-graph -T 'if(empty, "empty", "has_changes")'
   ```

3. **Remove empty/stale workspaces:**
   ```bash
   jj workspace forget <workspace-name>
   ```

**Safety notes:**

- Never remove the current workspace (marked with `*`)
- `jj workspace forget` doesn't delete files, it just removes the workspace tracking
- You can always recreate a workspace if needed
- This is a maintenance operation, not a destructive one

**Example workflow:**

```bash
# List workspaces
jj workspace list
# Output:
# default: sqxoqmn 7a9a3c5 (empty) (no description set)
# * feature-work: rlzxqmpv 0c4a1b2 Add login feature
# old-bugfix: xyz123ab (empty) (no description set)

# Remove empty workspaces
jj workspace forget default
jj workspace forget old-bugfix

# Verify
jj workspace list
# Output:
# * feature-work: rlzxqmpv 0c4a1b2 Add login feature
```

**What if I don't have multiple workspaces?**

If you only have one workspace (the default), this command won't do anything. Workspaces are optional - they're useful for:

- Working on multiple features simultaneously
- Code review without switching commits
- Parallel development on different branches

Show final state: !`jj workspace list`
