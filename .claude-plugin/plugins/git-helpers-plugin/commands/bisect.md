---
allowed-tools: Bash(git bisect*), mcp__git__git_log, mcp__git__git_show, mcp__git__git_diff, mcp__git__git_status, mcp__git__git_checkout
description: Help with git bisect to find problematic commits
model: sonnet
---

## Context

- Current status: !`git status`
- Recent commits: !`git log --oneline -20`

## Your task

Help the user perform a git bisect to identify which commit introduced a bug or regression.

### Git Bisect Commands:

1. **Start bisect**: `git bisect start`
2. **Mark current commit as bad**: `git bisect bad`
3. **Mark a known good commit**: `git bisect good <commit-hash>`
4. **Test and mark commits**:
   - `git bisect good` if the test passes
   - `git bisect bad` if the test fails
5. **Skip untestable commit**: `git bisect skip`
6. **View bisect log**: `git bisect log`
7. **End bisect session**: `git bisect reset`

### Workflow:

1. Start the bisect session
2. Mark the current commit as bad (if it has the bug)
3. Mark a known good commit (before the bug was introduced)
4. Git will checkout a commit in the middle for testing
5. Test the commit and mark it as good or bad
6. Repeat until the problematic commit is found
7. Reset when done

Ask the user:

- What issue are they trying to track down?
- Do they know a good commit where the issue didn't exist?
- Do they have a test command to verify if the issue is present?
