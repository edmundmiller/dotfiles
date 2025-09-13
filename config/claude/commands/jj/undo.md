---
allowed-tools: Bash(jj op log*), Bash(jj op undo*), Bash(jj op restore*), Bash(jj op show*), Bash(jj undo*), Bash(jj status*), Bash(jj log*)
description: Help recover from mistakes using jj's operation log
---

## Context

- Current state: !`jj status`
- Recent operations: !`jj op log --limit 10`
- Current commit: !`jj log -r @ --no-graph`
- Working directory: !`pwd`

## Your task

Help the user recover from mistakes or unwanted changes using jj's powerful operation log. Every jj operation is recorded and can be undone.

### Understanding the Operation Log

```bash
jj op log           # Show all operations with IDs and timestamps
jj op log --limit 5 # Show last 5 operations
jj op show ID       # Show details of specific operation
```

Each operation shows:
- Operation ID (like `8e8c38fe1c4f`)
- Timestamp
- User who performed it
- Description of what happened

### Undo Operations

#### 1. Simple Undo (last operation)
```bash
jj undo             # Undo the most recent operation
jj op undo          # Same as above
```

#### 2. Undo Specific Operation
```bash
jj op undo ID       # Undo a specific operation by ID
jj op undo -2       # Undo the second-to-last operation
```

#### 3. Restore to Point in Time
```bash
jj op restore ID    # Restore repo to state at operation ID
```
**Note**: Restore is more powerful than undo - it time-travels the entire repo

### Common Recovery Scenarios

**Undo a bad split:**
```bash
jj op log --limit 3         # Find the split operation
jj undo                     # If it was the last operation
# OR
jj op undo SPLIT_OP_ID      # Undo specific split
```

**Recover from accidental squash:**
```bash
jj op log | grep squash     # Find squash operations
jj op restore BEFORE_ID     # Restore to before squash
```

**Fix a wrong rebase:**
```bash
jj op log --limit 5         # Find the rebase
jj op show REBASE_ID        # Check what it did
jj op restore BEFORE_ID     # Go back to before rebase
```

**Undo Claude's changes:**
```bash
# If Claude just made changes you don't want
jj undo                     # Simple undo of last operation
# If Claude did multiple operations
jj op log --limit 10        # Review what happened
jj op restore SAFE_ID       # Restore to known good state
```

### Important Notes

- **Undo vs Restore**:
  - `undo`: Creates a new operation that reverses the effect
  - `restore`: Time-travels to exact previous state
  
- **Safety**: The operation log preserves everything - you can undo an undo!

- **Working copy**: After undo/restore, your working copy is updated

- **No data loss**: jj never loses data; everything is in the operation log

### Tips
1. Use `jj op log` frequently to understand what's happening
2. Note operation IDs before risky operations
3. `jj op restore` is your "emergency reset button"
4. You can even recover from `jj op restore` using another restore

Ask the user:
- What went wrong that needs undoing?
- Should we undo the last operation or something specific?
- Do they want to see the operation log first?
- Need help identifying which operation to undo?