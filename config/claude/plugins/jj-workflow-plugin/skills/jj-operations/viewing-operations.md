# Viewing Operations in Jujutsu

This document covers how to browse and understand the operation log using read-only viewing commands.

## Browsing Operation History

### `jj op log` - View All Operations

**Basic usage:**

```bash
jj op log                  # Show recent operations
jj op log --limit 20       # Show last 20 operations
jj op log --no-graph       # Show without graph visualization
```

**What you'll see:**

- Operation ID (12-character hash)
- Timestamp and duration
- Username and hostname
- Command that was executed
- High-level description of changes

**Example output interpretation:**

```
@  abc123def456 user@host 2025-01-05 14:23:45 -08:00
│  jj squash
│  squash commit xyz into abc

◉  789ghi012jkl user@host 2025-01-05 14:20:12 -08:00
│  jj describe -m "Add feature"
│  describe commit xyz
```

**Reading the log:**

- `@` marks the current operation (where you are now)
- Most recent operations at top
- Each operation shows what command created it
- Graph shows operation relationships

## Exploring What Changed

### `jj op show <op-id>` - See Operation Details

**Purpose:** Understand exactly what a specific operation changed.

**Usage:**

```bash
jj op show abc123def456    # Show what operation did
jj op show @               # Show current operation
jj op show @-              # Show previous operation
```

**What you'll see:**

- Operation metadata
- Which commits were modified
- What changed in each commit
- Bookmark movements
- Working copy changes

### `jj op diff` - Compare Repository States

**Purpose:** See differences between two operations or current vs past.

**Usage:**

```bash
# Compare current state with past operation
jj op diff --from abc123 --to @

# Compare two past operations
jj op diff --from abc123 --to def456

# See what operations changed
jj op diff --op abc123
```

**Use cases:**

- Understanding what went wrong between two points
- Seeing cumulative effect of several operations
- Debugging complex history issues

## Finding Operations

### By Time (Recent Mistakes)

```bash
jj op log --limit 10       # Show last 10 operations
# Look for operation just before mistake
```

### By Command (Specific Actions)

```bash
jj op log | grep "squash"  # Find all squash operations
jj op log | grep "describe"# Find all describe operations
# Identify the problematic operation
```

### By Description (What You Were Doing)

```bash
# Operation log shows what you ran
jj op log
# Look for descriptions like:
# "snapshot working copy"    → Auto-snapshots
# "jj describe"              → Commit descriptions
# "jj new"                   → Stack operations
# "jj squash"                → Squash operations
```

## Common Viewing Patterns

### "What Did I Just Do?"

```bash
jj op log --limit 5        # Recent operations
jj op show @               # Current operation details
```

### "What Changed in This Operation?"

```bash
jj op show abc123def456    # Show specific operation details
jj op diff --op abc123     # See the diff
```

### "Compare Two Points in Time"

```bash
jj op log                  # Find two operations
jj op diff --from abc123 --to def456  # Compare them
```
