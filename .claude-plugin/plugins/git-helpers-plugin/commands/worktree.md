---
allowed-tools: Bash(git worktree*), mcp__git__git_branch, mcp__git__git_status, mcp__git__git_log, Bash(ls*), Bash(pwd)
description: Create and manage git worktrees for parallel development
model: sonnet
---

## Context

- Current directory: !`pwd`
- Current git status: !`git status`
- Available branches: !`git branch -a`
- Existing worktrees: !`git worktree list`

## Your task

Help the user create and manage git worktrees. Worktrees allow working on multiple branches simultaneously without switching.

### Git Worktree Commands:

#### 1. Create a New Worktree

```bash
# Create worktree for existing branch
git worktree add <path> <branch>

# Create worktree with new branch
git worktree add -b <new-branch> <path> [<start-point>]

# Create detached worktree at specific commit
git worktree add --detach <path> <commit>
```

#### 2. List Worktrees

```bash
git worktree list           # List all worktrees
git worktree list --porcelain  # Machine-readable format
```

#### 3. Remove Worktree

```bash
git worktree remove <path>  # Remove a worktree
git worktree remove --force <path>  # Force removal
```

#### 4. Maintenance Commands

```bash
git worktree prune          # Clean up stale worktrees
git worktree lock <path>    # Prevent automatic pruning
git worktree unlock <path>  # Allow pruning again
```

### Common Use Cases:

1. **Hotfix while working on feature**:

   ```bash
   git worktree add ../hotfix main
   cd ../hotfix
   # Make hotfix changes
   ```

2. **Review PR without losing work**:

   ```bash
   git worktree add ../review origin/pr-branch
   ```

3. **Parallel feature development**:
   ```bash
   git worktree add -b feature-2 ../feature-2
   ```

### Best Practices:

- Use descriptive paths that match branch names
- Clean up worktrees when done (`git worktree remove`)
- Don't create worktrees inside existing worktrees
- Consider a dedicated directory for all worktrees (e.g., `../worktrees/`)

Ask the user:

- Do they want to create a new worktree or manage existing ones?
- What branch do they want to work on?
- Where should the worktree be created?
