# Time Travel: Viewing Past States

This document covers how to explore the repository at past operations without modifying your current state.

## The `--at-op` Flag

**Purpose:** View the repository as it was at any past operation without changing current state.

**Key concept:** This is **read-only time travel**. You're peeking at history, not modifying anything.

## Works with Read-Only Commands

The `--at-op` flag can be used with any read-only jj command:

```bash
jj log --at-op=<op-id>     # See commit history at that operation
jj status --at-op=<op-id>  # See working copy state
jj diff --at-op=<op-id>    # See changes at that time
jj show --at-op=<op-id>    # See specific commit at that time
```

**Important:** Working copy is **NOT** modified. You're just viewing how things were.

## Basic Exploration Workflow

### 1. Find Operation of Interest

```bash
jj op log                  # Browse operation history
```

### 2. View Repo State at That Operation

```bash
jj log --at-op=abc123def456
```

### 3. Compare with Current State

```bash
jj log                     # Current state
jj log --at-op=abc123      # Past state
```

### 4. See What Changed in Working Copy

```bash
jj diff --at-op=abc123
```

## Exploring to Find Right Restore Point

**Problem:** You know something went wrong, but not sure which operation to restore to.

**Solution:** Use `--at-op` to explore without committing:

```bash
# 1. Start with operation log
jj op log

# 2. Use --at-op to peek at different states
jj log --at-op=abc123      # Is this the right state?
jj status --at-op=abc123   # Check working copy
jj diff --at-op=abc123     # See changes

# 3. Try different operations until you find the right one
jj log --at-op=def456      # Or this one?
jj log --at-op=ghi789      # Found it!

# 4. When you find it, restore (see restoring-operations.md)
jj op restore ghi789       # Now actually restore
```

## Time Travel Patterns

### "Find When Things Broke"

```bash
jj op log                  # Browse operations

# Bisect through time with --at-op
jj log --at-op=<candidate>
jj log --at-op=<earlier>
jj log --at-op=<evenEarlier>

# Find last good state, then restore to it
```

### "Compare Now vs Then"

```bash
# View current state
jj log
jj status

# View past state
jj log --at-op=abc123
jj status --at-op=abc123

# Compare
jj op diff --from abc123 --to @
```

### "See Commit History Evolution"

```bash
# How did the log look after each operation?
jj log --at-op=abc123      # After operation 1
jj log --at-op=def456      # After operation 2
jj log --at-op=ghi789      # After operation 3
```

## Advantages of Time Travel

**Safe exploration:**

- ✅ No risk of breaking current state
- ✅ Try multiple candidates before committing
- ✅ Understand what changed between operations
- ✅ Make informed decisions about restoring

**When to use:**

- Not sure which operation to restore to
- Want to understand history before taking action
- Debugging complex repository states
- Learning how operations affected the repository

## Important Notes

**Automatic snapshotting is disabled:** When using `--at-op`, jj doesn't snapshot the working copy before the command.

**Read-only only:** You cannot modify the repository while viewing at a past operation. Use `jj op restore` for that (see restoring-operations.md).

**No working copy modification:** Your files on disk don't change. You're viewing metadata about how the repo was structured at that point.
