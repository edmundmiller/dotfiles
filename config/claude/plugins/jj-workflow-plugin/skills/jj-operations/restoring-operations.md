# Restoring to Past Operations

This document covers how to restore the repository to past operations and recover from complex mistakes.

## The `jj op restore` Command

**Purpose:** Return the entire repository to the state at a specific operation.

**Key concept:** This is **actual time travel**. You're changing your repository state, not just viewing.

### What It Does

- Restores all commits to their state at that operation
- Updates bookmarks to their past positions
- Restores working copy to match that operation
- Creates a NEW operation recording this restoration

**Important:** `jj op restore` is itself an operation, so it's also undoable with `jj undo`.

## Basic Restore Workflow

### 1. Find the Operation You Want

```bash
jj op log
```

### 2. Restore to That Operation

```bash
jj op restore abc123def456
```

### 3. Verify the Restoration

```bash
jj status
jj log
```

## Example: Recovering from Bad Squash

```bash
# Oh no, squashed wrong commits!
jj op log                  # Find operation before squash
# See: xyz789abc123 was before the bad squash
jj op restore xyz789abc123 # Jump back before mistake
# Repository now as it was before squash
```

## Finding the Right Operation to Restore

See `time-travel.md` for exploration techniques using `--at-op` to find the right operation before committing to a restore.

### Strategy 1: By Time (Recent Mistake)

```bash
jj op log --limit 10       # Show last 10 operations
# Look for operation just before mistake
# Restore to that operation
```

### Strategy 2: By Command (Find Specific Action)

```bash
jj op log | grep "squash"  # Find all squash operations
jj op log | grep "describe"# Find all describe operations
# Identify the problematic operation
# Restore to operation before it
```

### Strategy 3: By Exploration (Step Through History)

```bash
# Use --at-op to explore without committing
jj op log
jj log --at-op=abc123      # Is this the right state?
jj log --at-op=def456      # Or this one?
jj log --at-op=ghi789      # Found it!
jj op restore ghi789       # Now actually restore
```

## Complex Recovery Scenarios

### Scenario 1: Multiple Bad Operations

**Problem:** Made several mistakes in a row, need to go back before all of them.

**Solution:**

```bash
# 1. Find operations
jj op log --limit 20

# 2. Identify last good operation
jj log --at-op=<candidate> # Explore candidates

# 3. Restore to last good state
jj op restore <last-good-op>
```

### Scenario 2: Not Sure Which Operation to Restore

**Problem:** Complex history, unclear which operation to restore to.

**Solution - Use time travel to explore:**

```bash
# 1. Start with operation log
jj op log

# 2. Use --at-op to peek at different states
jj log --at-op=abc123
jj status --at-op=abc123
jj diff --at-op=abc123

# 3. Try different operations until you find the right one
jj log --at-op=def456
jj log --at-op=ghi789

# 4. When you find it, restore
jj op restore ghi789
```

### Scenario 3: Want to See Specific Change

**Problem:** Need to understand what a particular operation did.

**Solution:**

```bash
# 1. Find the operation
jj op log | grep "squash"  # or other command

# 2. Show what it changed
jj op show abc123def456

# 3. Compare before/after
jj log --at-op=abc123@-    # Before
jj log --at-op=abc123      # After

# 4. See diff
jj op diff --op abc123
```

### Scenario 4: Concurrent Operations (Advanced)

**Problem:** Multiple jj commands ran concurrently, created divergent operations.

**What happened:** Jj is lock-free, so concurrent operations create separate branches in the operation log.

**Solution:**

```bash
# 1. View operation log - will show divergence
jj op log

# 2. Identify which branch is correct
jj log --at-op=<branch1>
jj log --at-op=<branch2>

# 3. Restore to correct branch
jj op restore <correct-branch>
```

## Safety Considerations

### Restore is Undoable

Since `jj op restore` creates a new operation, you can undo it:

```bash
jj op restore abc123       # Restore to operation
# Oops, that was wrong
jj undo                    # Undo the restore
```

### What Restore Affects

**Does affect:**

- ✅ All commits and their states
- ✅ Bookmark positions
- ✅ Working copy files (updates to match restored state)
- ✅ Repository structure

**Does NOT affect:**

- ❌ The operation log itself (restore is recorded)
- ❌ Remote repositories until you push
- ❌ Other people's concurrent operations

### You Can't Lose Work

Even after restoring, the "future" operations still exist in the operation log. You can always restore forward again:

```bash
jj op restore abc123       # Go back
# Do some work...
jj op log                  # See all operations, including "future" ones
jj op restore def456       # Restore to future state
```

## When to Use Restore vs Undo

**Use `jj undo`** (see jj-undo skill):

- Quick recent mistake (1-2 operations ago)
- Simple, immediate reversal

**Use `jj op restore`:**

- Need to jump back multiple operations at once
- Know the specific operation ID you want
- Want to skip over several intermediate operations
- Complex recovery from multiple mistakes

**Relationship:**

- `jj undo` = `jj op restore @-` (restore to parent operation)
- `jj undo` twice = `jj op restore @--` (go back 2 operations)
