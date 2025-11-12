---
name: Understanding Jujutsu Working Copy Snapshots
description: Understand working copy auto-snapshots, evolog, and how jj tracks changes automatically. Use when understanding @, viewing working copy history, managing unfinished work, or understanding how jj prevents data loss.
allowed-tools: Bash(jj evolog:*), Bash(jj status:*), Bash(jj log:*), Bash(jj obslog:*), Bash(jj restore:*), Bash(jj describe:*), Read(*/jj-working-copy-snapshots/*.md)
---

# Understanding Jujutsu Working Copy Snapshots

## Overview

**Key insight:** Jujutsu automatically snapshots your working directory before every command. This creates an automatic safety net - you can always recover your work, even unfinished changes.

The working copy commit (`@`) is your current workspace, and its evolution is tracked in detail.

## Core Concepts

### The Working Copy Commit (`@`)

**What is `@`?**
- Your current working directory as a commit
- Automatically updated before each jj command
- Has a change ID that persists across amendments
- Marked with `@` in `jj log` output

**Key properties:**
```bash
jj log -r @           # Show current working copy commit
jj status             # Show what's in @ vs parent
jj diff -r @          # Show changes in working copy
```

### Automatic Snapshotting

**How it works:**

1. **Before every jj command:** Working directory → snapshot
2. **Command executes:** Operates on commits
3. **After command:** Working directory updated if needed

**What this means:**
- You can't lose work by running jj commands
- Every change is recorded somewhere
- `jj op log` shows when snapshots happened

**Example:**
```bash
# Make some changes to files
echo "hello" > file.txt

# Run ANY jj command - working copy is snapshotted first
jj log

# Your changes are now saved in @
jj status  # Shows file.txt as modified
```

### Evolution Log (`evolog`)

**What is evolog?**
Shows the evolution history of a commit's change ID, including all amendments and snapshots.

**View working copy evolution:**
```bash
jj evolog              # Show @ evolution
jj evolog -r <change-id>  # Show specific change evolution
```

**Example output:**
```
@  abc123 (current) My feature
│  <working copy snapshot>
◆  abc123 (previous) My feature
│  <working copy snapshot>
◆  abc123 (earlier) My feature
```

All these commits share the same change ID (`abc123`) but different commit IDs - they're the evolution of the same logical change.

## Common Use Cases

### Viewing Working Copy History

**Problem:** Want to see how working copy evolved.

```bash
# See all snapshots of current change
jj evolog

# See evolution with patches
jj evolog --patch

# See evolution with file diffs
jj evolog -p
```

### Recovering Lost Work

**Problem:** Made changes, ran some commands, want to get back to earlier state.

**Solution:**

1. **Check evolution:**
   ```bash
   jj evolog --patch
   ```

2. **Find the right snapshot:**
   Look through the evolution log for the state you want

3. **Restore from that snapshot:**
   ```bash
   jj restore --from <commit-id>  # Restore files from specific snapshot
   ```

**Or use operation log:**
```bash
jj op log                    # Find operation before changes
jj --at-op=<op-id> show      # View state at that operation
jj op restore <op-id>        # Restore to that operation
```

### Managing Unfinished Work

**Problem:** Working on something but need to switch tasks.

**Solution:** Just use `jj new` to stack work, or leave it as-is. Everything is auto-saved.

**Option 1: Stack with `jj new`** (recommended)
```bash
# Your current work is auto-saved in @
jj new  # Creates new commit, moves @ to child

# Now @ is empty and ready for new work
# Previous work is in @- (parent)
```

**Option 2: Just switch** (works too)
```bash
# Your work is auto-snapshotted
jj edit <other-commit>  # Switch to other commit

# Changes in working directory are saved automatically
# Return later: jj edit <original-change-id>
```

**Option 3: Describe and continue** (explicit)
```bash
# Describe current work
jj describe -m "WIP: feature in progress"

# Create new commit for next task
jj new -m "Start other task"
```

### Preventing Commits of Certain Files

**Problem:** Want to keep scratch files without committing them.

**Solutions:**

#### 1. Use `.gitignore` (simplest)
```bash
# Add to .gitignore
echo "scratch/" >> .gitignore
echo "*.tmp" >> .gitignore

# These files won't be auto-tracked
```

#### 2. Configure `snapshot.auto-track`
```toml
# ~/.jjconfig.toml
[snapshot]
auto-track = "none"  # Don't auto-track new files
# Or use glob patterns
auto-track = "glob:src/**"  # Only track src/
```

#### 3. Use separate directory
```bash
# Keep scratch work outside repo
mkdir ~/scratch-work/myproject
# Work there for temporary stuff
```

## Auto-Tracking Configuration

**Control what gets auto-tracked:**

```toml
# ~/.jjconfig.toml or .jj/repo/config.toml
[snapshot]
# Options:
# - "all" (default): Track all new files
# - "none": Don't track any new files
# - glob patterns: Track only matching files
auto-track = "all"
```

**Examples:**

```toml
# Only track source files
[snapshot]
auto-track = "glob:src/**/*.rs"

# Track everything except scratch
[snapshot]
auto-track = "!glob:scratch/**"

# Don't auto-track new files
[snapshot]
auto-track = "none"
```

**With `auto-track = "none"`:**
```bash
# Manually add files
jj file track path/to/file

# Or add temporarily
jj file track --temporary path/to/file
```

## When to Use This Skill

Use this skill when:
- ✅ Understanding how @ works
- ✅ Viewing working copy history
- ✅ Recovering lost or overwritten changes
- ✅ Managing unfinished or WIP work
- ✅ Configuring auto-tracking behavior
- ✅ Understanding jj's safety guarantees

Don't use this skill for:
- ❌ Operation history (see jj-operations skill)
- ❌ Undo operations (see jj-undo skill)
- ❌ Commit organization (see commit-curation skill)

## Progressive Disclosure

For detailed FAQ answers and advanced patterns:

📚 **See detailed docs:** `faq-reference.md`

This includes:
- Complete FAQ answers about working copy
- Advanced evolog patterns
- Private changes workflow
- Moving changes between commits
- Configuration details

## Quick Reference

```bash
# Working copy inspection
jj status                      # Show working copy changes
jj log -r @                    # Show current commit
jj diff -r @                   # Show working copy diff

# Evolution history
jj evolog                      # Show @ evolution
jj evolog --patch              # With diffs
jj evolog -r <change-id>       # Specific change evolution
jj obslog                      # Alias for evolog

# Recovery
jj restore --from <commit-id>  # Restore files from snapshot
jj op log                      # View operation history
jj op restore <op-id>          # Restore to operation

# Auto-tracking
jj file track <path>           # Track specific file
jj file untrack <path>         # Untrack file
```

## Remember

**Every jj command snapshots your work first.** You can't lose uncommitted changes. Use `jj evolog` to see the history of your working copy, and `jj op log` to see all operations that created snapshots.
