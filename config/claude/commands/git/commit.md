---
allowed-tools: mcp__git__git_status, mcp__git__git_diff_unstaged, mcp__git__git_diff_staged, mcp__git__git_diff, mcp__git__git_add, mcp__git__git_commit, mcp__git__git_log, mcp__git__git_branch
description: Create a git commit using MCP git server
---

## Context

- Current git status: !`git status`
- Unstaged changes: !`git diff`
- Staged changes: !`git diff --staged`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`

## Your task

Based on the above changes, create a single git commit.

Analyze the changes and determine the appropriate conventional commit type:

   - `feat:` for new features
   - `fix:` for bug fixes
   - `docs:` for documentation changes
   - `style:` for formatting changes
   - `refactor:` for code refactoring
   - `test:` for test additions/changes
   - `chore:` for maintenance tasks

Remember: This project follows Conventional Commits specification.

Use `mcp__git__git_add` to stage files if needed, then use `mcp__git__git_commit` to create the commit.