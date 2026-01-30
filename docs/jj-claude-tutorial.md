# Using Jujutsu (jj) with Claude Code

This tutorial will teach you how to effectively use Jujutsu (jj) version control with Claude Code for a more efficient development workflow.

## Core Concepts

### 1. Working Copy as a Commit

In jj, your working directory is always a commit (the "working-copy commit" shown as `@`). This means:

- All changes are automatically tracked - no staging area needed
- You can directly edit any commit in history
- Every operation is recorded and can be undone

### 2. The @ Symbol

- `@` refers to the current working-copy commit
- `@-` refers to its parent commit
- `@--` refers to its grandparent, and so on

## Essential Workflows

### Starting Fresh Work

```bash
# Start new work from main branch
jj new main

# Make your changes
hey rebuild  # or edit files as needed

# Describe what you're doing
jj describe -m "feat(zsh): add new completion system"

# Continue with more changes and commit when ready
jj commit -m "feat(zsh): implement tab completion for custom commands"
```

### Checking Your Status

```bash
# See what's changed in your working copy
jj status

# View the diff of your current changes
jj diff

# See the commit graph
jj log

# See operations history (every jj command is recorded!)
jj op log
```

### Splitting Your Work

When you've made multiple unrelated changes:

```bash
# Interactive split - opens your editor to select what to split out
jj split

# After splitting, you'll have two commits:
# - One with the changes you selected
# - Your working copy with the remaining changes
```

### Fixing a Previous Commit

```bash
# Let's say you need to fix commit 'abc123'
jj edit abc123

# Make your fixes
vim config/zsh/.zshrc

# The changes are automatically part of that commit
# Return to where you were
jj new @
```

### Squashing Changes

```bash
# Squash current changes into parent
jj squash

# Squash into a specific commit
jj squash --into abc123

# With a message
jj squash -m "fixes from review"
```

## Git Integration

### Working with Git Remotes

```bash
# Clone a Git repository
jj git clone https://github.com/user/repo.git

# Fetch latest changes
jj git fetch

# Push your work (creates/updates branch automatically)
jj git push --change @-

# Push with a specific branch name
jj bookmark create my-feature -r @-
jj git push --bookmark my-feature
```

### Co-located Repositories (jj + git in same directory)

Your dotfiles repo is co-located, meaning both jj and git work together:

```bash
# jj automatically syncs with git
jj git export  # Updates git with jj changes
jj git import  # Updates jj with git changes

# These happen automatically in co-located repos!
```

## Claude Code Specific Tips

### 1. Using the `hey` Command

Your dotfiles repo has a custom `hey` command that wraps common operations:

```bash
hey rebuild  # Rebuild system configuration
hey test     # Test configuration without switching
hey rollback # Rollback to previous generation
```

### 2. Committing with Claude Code

When ready to commit:

```bash
# jj handles the actual version control
jj commit -m "your message"

# If you need to push to GitHub
jj git push --change @-
```

### 3. Undoing Mistakes

```bash
# See what operations you can undo
jj op log

# Undo the last operation
jj undo

# Restore to a specific operation
jj op restore <operation-id>
```

## Common Patterns

### Pattern 1: Feature Development

```bash
jj new main                          # Start from main
# ... make changes ...
jj commit -m "feat: add feature"    # Commit your work
jj git push --change @-              # Push to GitHub
```

### Pattern 2: Quick Fix

```bash
jj new                               # Start fresh
# ... make fix ...
jj squash -m "fix: resolve issue"   # Squash into parent
jj git push                          # Push the branch
```

### Pattern 3: Multiple Related Changes

```bash
jj new main                          # Start from main
# ... make first change ...
jj commit -m "refactor: extract function"
# ... make second change ...
jj commit -m "feat: add new capability"
# ... make third change ...
jj describe -m "docs: update readme"
jj git push -r main..@               # Push all commits
```

## Key Differences from Git

| Git Command             | jj Equivalent                      | Notes                                              |
| ----------------------- | ---------------------------------- | -------------------------------------------------- |
| `git add`               | (automatic)                        | jj tracks all changes automatically                |
| `git commit`            | `jj commit`                        | Creates new commit and moves to fresh working copy |
| `git commit --amend`    | `jj squash`                        | Squashes current changes into parent               |
| `git checkout <branch>` | `jj new <branch>`                  | Creates new commit on top of branch                |
| `git rebase -i`         | `jj edit`, `jj squash`, `jj split` | Direct manipulation instead of interactive rebase  |
| `git stash`             | `jj new`                           | Just start a new commit, old work stays as-is      |
| `git log`               | `jj log`                           | Shows graph by default                             |
| `git status`            | `jj status`                        | Shows working-copy commit info                     |
| `git diff`              | `jj diff`                          | Shows diff of working copy vs parent               |

## Advanced Tips

### 1. Revsets

jj has a powerful query language for selecting commits:

```bash
# All your commits
jj log -r 'author(emiller)'

# Commits not yet pushed
jj log -r 'remote_bookmarks()..@'

# Branches without remotes
jj log -r 'bookmarks() & ~remote_bookmarks()'
```

### 2. Working with Multiple Changes

Since every directory state is a commit, you can easily jump around:

```bash
# Work on feature A
jj new main
# ... changes for feature A ...
jj describe -m "WIP: feature A"

# Need to fix something else quickly?
jj new main  # Start fresh from main
# ... make fix ...
jj commit -m "fix: urgent issue"
jj git push --change @-

# Return to feature A
jj edit <commit-id-of-feature-A>
# Continue where you left off!
```

### 3. The Operation Log is Your Safety Net

Everything in jj is undoable because it tracks operations:

```bash
# Messed up a rebase?
jj op log
jj op restore <before-rebase-operation>

# Accidentally squashed the wrong commits?
jj undo

# Want to see what changed in an operation?
jj op diff <operation-id>
```

## Quick Command Reference

```bash
# Basics
jj status          # Current state
jj diff            # Current changes
jj log             # Commit graph

# Creating commits
jj new             # New commit from current
jj new <rev>       # New commit from revision
jj commit -m "msg" # Finalize and start fresh
jj describe -m "msg" # Set commit message

# Editing history
jj edit <rev>      # Edit a specific commit
jj squash          # Squash into parent
jj split           # Split current commit
jj rebase -r <rev> -d <dest> # Move commits

# Git integration
jj git fetch       # Fetch from remote
jj git push        # Push current branch
jj git push --change <rev> # Push specific commit

# Safety
jj undo            # Undo last operation
jj op log          # Show operations
jj op restore <id> # Restore to operation
```

## Practice Exercises

Try these in your dotfiles repo:

1. **Create a test commit**: Make a small change, commit it, then undo
2. **Split a commit**: Make two unrelated changes, then split them
3. **Fix an old commit**: Edit a previous commit, make a change, return to latest
4. **Use the operation log**: Make changes, check op log, restore to previous state

Remember: In jj, you can't lose work - the operation log tracks everything!
