---
allowed-tools: Bash(git rebase*), Bash(git rebase --*), mcp__git__git_log, mcp__git__git_status, mcp__git__git_branch, mcp__git__git_diff, mcp__git__git_show
description: Help with git rebase operations
---

## Context

- Current status: !`git status`
- Current branch: !`git branch --show-current`
- Recent commits on current branch: !`git log --oneline -10`
- All branches: !`git branch -a`

## Your task

Help the user perform a git rebase operation. Common rebase scenarios:

### 1. Interactive Rebase (Edit History)
```bash
git rebase -i HEAD~N  # N is number of commits to go back
```
Interactive rebase allows you to:
- Reorder commits
- Squash commits together
- Edit commit messages
- Drop commits
- Split commits

### 2. Rebase onto Another Branch
```bash
git rebase <target-branch>  # Rebase current branch onto target
git rebase --onto <new-base> <old-base> <branch>  # More complex rebase
```

### 3. Rebase Commands During Conflict Resolution
```bash
git rebase --continue  # After resolving conflicts
git rebase --skip      # Skip current commit
git rebase --abort     # Cancel rebase and return to original state
```

### 4. Common Options
```bash
git rebase -i --autosquash  # Auto-organize fixup!/squash! commits
git rebase --preserve-merges  # Keep merge commits
git rebase --committer-date-is-author-date  # Preserve dates
```

### Important Notes:
- **Never rebase commits that have been pushed to a shared branch** (unless coordinated with team)
- Rebase rewrites history - force push will be needed for pushed branches
- Always ensure working directory is clean before rebasing

### Claude Code Version Issue
If slash commands aren't working, this Reddit comment mentions Claude Code v1.0.88 worked better:
https://www.reddit.com/r/ClaudeAI/comments/1ndafeq/comment/ndfazn5/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button

```bash
# Downgrade to working version
curl -O https://raw.githubusercontent.com/Homebrew/homebrew-cask/b7821349a0cd7186157cc5e2ae4e3ef1e52eddb2/Casks/c/claude-code.rb && brew install claude-code.rb

# Disable auto-updates to prevent upgrading
claude config set -g autoUpdates false
```

Ask the user:
- What type of rebase do they want to perform?
- Are they rebasing unpushed commits or coordinating with a team?
- Do they need help with conflict resolution?