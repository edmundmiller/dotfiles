---
allowed-tools: Bash(jj describe*), Bash(jj log*), Bash(jj status*), Bash(jj show*)
description: Help write and update commit descriptions
---

## Context

- Current commit: !`jj log -r @ --no-graph`
- Recent commits: !`jj log -r ::@ --limit 5`
- Current changes: !`jj status`
- Existing description: !`jj log -r @ --no-graph -T 'description'`

## Your task

Help the user write clear, informative commit descriptions following best practices.

### Describe Commands

#### 1. Basic Description
```bash
jj describe -m "message"     # Set description for working copy
jj describe                  # Open editor for multi-line description
```

#### 2. Describe Other Commits
```bash
jj describe -r REVISION -m "message"  # Describe specific commit
jj describe -r @- -m "message"        # Describe parent
jj describe -r abc123 -m "message"    # Describe by change ID
```

#### 3. Batch Descriptions
```bash
# Describe multiple commits after splitting
jj describe -r @-- -m "refactor: extract helper functions"
jj describe -r @- -m "test: add unit tests"  
jj describe -m "docs: update README"
```

### Commit Message Format

Follow conventional commits when appropriate:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation only
- `style:` Formatting, no code change
- `refactor:` Code restructuring
- `test:` Adding tests
- `chore:` Maintenance tasks
- `perf:` Performance improvements

#### Good Description Structure
```
type(scope): short summary (50 chars or less)

Longer explanation if needed (wrap at 72 chars).
Explain what and why, not how.

- Bullet points for multiple changes
- Keep related items together
- Use imperative mood ("add" not "added")

Fixes: #123
Co-authored-by: Assistant <assistant@example.com>
```

### Common Workflows

**After Claude makes changes:**
```bash
jj status                          # Review what changed
jj diff                           # Examine the changes
jj describe -m "fix: resolve race condition in worker pool

Claude identified and fixed a race condition where workers
could access shared state without proper synchronization.
Added mutex locks around critical sections."
```

**Update after splitting:**
```bash
jj split                          # Split changes first
jj log -r ::@                     # See new structure
jj describe -r @- -m "test: ..." # Describe first part
jj describe -m "feat: ..."        # Describe second part
```

**Amend existing description:**
```bash
jj describe                       # Opens editor with current message
# Edit and save to update
```

### Best Practices
- Write in imperative mood ("add" not "added")
- First line should be concise summary (50 chars)
- Separate summary from body with blank line
- Explain why the change was made, not just what
- Reference issues/tickets when relevant
- Credit co-authors when appropriate

Ask the user:
- What type of change is this (feat/fix/docs/etc)?
- Should we follow conventional commit format?
- Any issue numbers or context to reference?
- Need help summarizing the changes?