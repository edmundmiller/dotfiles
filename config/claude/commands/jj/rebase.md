---
allowed-tools: Bash(jj rebase*), Bash(jj status*), Bash(jj log*), Bash(jj branch list*), Bash(jj op log*), Bash(jj abandon*)
description: Help reorganize commits and resolve rebase conflicts
---

## Context

- Current commit: !`jj log -r @ --no-graph`
- Commit chain: !`jj log -r ::@ --limit 10`
- Branches: !`jj branch list`
- Current status: !`jj status`

## Your task

Help the user rebase commits to reorganize history or update to latest changes. In jj, rebasing is conflict-free and automatic.

### Rebase Commands

#### 1. Rebase Current Commit
```bash
jj rebase -d DESTINATION    # Rebase @ onto destination
jj rebase -d main          # Rebase onto main branch
jj rebase -d @--           # Rebase onto grandparent
```

#### 2. Rebase Specific Commits
```bash
jj rebase -r REVISION -d DESTINATION  # Rebase specific commit
jj rebase -s SOURCE -d DESTINATION    # Rebase source and descendants
```

#### 3. Rebase Branch
```bash
jj rebase -b BRANCH -d DESTINATION    # Rebase entire branch
```

### Key Differences from Git
- **Always succeeds**: Conflicts become part of the commit
- **Non-interactive**: No step-by-step editing
- **Automatic**: Descendants are rebased automatically
- **Reversible**: Use `jj op undo` to reverse any rebase

### Common Workflows

**Update feature branch with main:**
```bash
jj rebase -d main           # Rebase current work onto main
jj log -r ::@               # Verify new structure
```

**Reorganize commits:**
```bash
# Move a commit earlier in history
jj rebase -r COMMIT_ID -d NEW_PARENT
```

**Rebase after fetch:**
```bash
jj git fetch                # Get latest changes
jj rebase -d main@origin    # Rebase onto updated main
```

**Linear history from parallel work:**
```bash
# If you have parallel branches
jj rebase -r COMMIT1 -d main
jj rebase -r COMMIT2 -d COMMIT1
```

### Handling Conflicts

In jj, conflicts don't stop the rebase:
```bash
jj rebase -d main           # Rebase happens even with conflicts
jj status                   # Shows conflict markers if any
# Fix conflicts in files
jj squash                   # Resolve and continue
```

### Advanced Rebase Operations

**Rebase only part of a branch:**
```bash
jj rebase -s START -d DESTINATION  # Rebase from START onwards
```

**Rebase and abandon old commits:**
```bash
jj rebase -r @ -d main
jj abandon OLD_COMMIT_ID    # Clean up old commits
```

**Rebase preserving commit structure:**
```bash
# jj automatically preserves descendant relationships
jj rebase -r PARENT -d NEW_DESTINATION
# All children follow automatically
```

### Recovery from Bad Rebase
```bash
jj op log | grep rebase     # Find the rebase operation
jj op undo                  # Undo if it was recent
jj op restore BEFORE_ID     # Restore to before rebase
```

### Tips
- Use `jj log` with graph to visualize before rebasing
- Rebasing in jj is always safe - you can undo anything
- Conflicts are stored in commits, not working directory
- Consider `jj evolve` for automatic rebasing of stacks

Ask the user:
- What commits need rebasing?
- Where should they be rebased to?
- Is this to update with upstream or reorganize history?
- Any conflicts to resolve after rebasing?