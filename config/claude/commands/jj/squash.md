---
allowed-tools: Bash(jj squash*), Bash(jj status*), Bash(jj log*), Bash(jj diff*), Bash(jj show*)
description: Help combine changes into parent commits
---

## Context

- Current working copy: !`jj log -r @ --no-graph`
- Parent commit: !`jj log -r @- --no-graph`
- Current changes: !`jj status`
- Commit chain: !`jj log -r ::@ --limit 5`

## Your task

Help the user squash (combine) changes into parent commits. This is useful for cleaning up incremental work or combining related changes.

### Squash Operations

#### 1. Basic Squash (into parent)
```bash
jj squash           # Squash current changes into parent
jj squash -m "msg"  # Squash with new message
```

#### 2. Interactive Squash
```bash
jj squash -i        # Choose which changes to squash
```
Opens diff editor to select specific changes to move into parent

#### 3. Squash Specific Files
```bash
jj squash path/to/file.js    # Squash only specific files
jj squash -i src/            # Interactive squash from directory
```

#### 4. Squash Into Non-Parent
```bash
jj squash --into TARGET_REV   # Squash into a different commit
jj squash --from REV --into TARGET  # Move changes between commits
```

### Common Claude + jj Workflows

**Clean up incremental fixes:**
```bash
# After Claude makes several small fixes
jj log -r ::@              # Review commit chain
jj squash                  # Combine with parent
jj describe -m "fix: complete solution"
```

**Partial squash:**
```bash
# When only some changes belong together
jj squash -i               # Interactive selection
jj describe -r @-          # Update combined commit message
```

**Squash before push:**
```bash
# Clean history before sharing
jj squash                  # Combine work
jj log -r @                # Verify result
jj git push --change @     # Push to remote
```

### Important Considerations
- Squashing rewrites history - don't squash already-pushed commits
- Empty commits are automatically abandoned
- Use `jj op undo` if squash goes wrong
- Interactive squash uses your configured diff editor (hunk.nvim)

### When to Squash vs Split
- **Squash**: Combining related changes, cleaning up WIP commits
- **Split**: Separating unrelated changes, organizing by feature

Ask the user:
- Should we squash everything or select specific changes?
- Do they want to update the commit message?
- Is this preparing for a push to remote?