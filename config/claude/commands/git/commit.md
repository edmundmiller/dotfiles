---
allowed-tools: mcp__git__git_status, mcp__git__git_diff_unstaged, mcp__git__git_diff_staged, mcp__git__git_diff, mcp__git__git_add, mcp__git__git_commit, mcp__git__git_log, mcp__git__git_branch
description: Create a git commit using MCP git server
---

## Context

- Current git status: !`mcp__git__git_status(repo_path=".")`
- Unstaged changes: !`mcp__git__git_diff_unstaged(repo_path=".")`
- Staged changes: !`mcp__git__git_diff_staged(repo_path=".")`
- Current branch: !`mcp__git__git_branch(repo_path=".", branch_type="local")`
- Recent commits: !`mcp__git__git_log(repo_path=".", max_count=10)`

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