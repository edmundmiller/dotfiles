---
name: Exploring Operation History in Jujutsu
description: Help users explore operation history and time travel in jj. Use when the user explicitly mentions 'operation log', 'op log', 'jj op', or 'operation history'. Covers jj op log, --at-op flag, op restore, and operation exploration.
allowed-tools: Bash(jj op log:*), Bash(jj op show:*), Bash(jj op restore:*), Bash(jj op diff:*), Bash(jj log --at-op:*), Bash(jj status:*), Bash(jj diff --at-op:*), Read(*/jj-operations/*.md)
---

# Exploring Operation History in Jujutsu

## Overview

**The operation log is your safety net.** Every repository-modifying command is recorded with complete snapshots, allowing full time travel and recovery.

**Key insight:** Each operation contains metadata (timestamp, user, command) plus a snapshot of all commit states, bookmarks, and repository structure.

## When to Use Operation Log

**Use operation log when:**

- ✅ You need to understand what you've been doing
- ✅ You want to find a specific past state
- ✅ You need to recover from complex mistakes
- ✅ You're debugging unexpected repository state
- ✅ You want to see history of changes to a commit

**Don't use operation log when:**

- ❌ You just need to undo the last operation (use `jj undo` from jj-undo skill)
- ❌ You're looking at commit history (use `jj log`)
- ❌ You want to see file changes (use `jj diff`)

## Core Capabilities

### 1. Viewing Operations (Read-Only)

Browse operation history and see what changed.

**Commands:** `jj op log`, `jj op show`, `jj op diff`

**When to use:** You want to understand what operations happened, what they changed, or compare repository states.

📚 **See detailed docs:** `viewing-operations.md`

### 2. Time Travel (Read-Only)

View the repository at any past operation without modifying current state.

**Commands:** `--at-op` flag with `jj log`, `jj status`, `jj diff`, etc.

**When to use:** You want to explore past states, compare with current state, or find the right operation to restore.

📚 **See detailed docs:** `time-travel.md`

### 3. Restoring to Past Operations

Jump the entire repository back to a specific operation state.

**Commands:** `jj op restore <op-id>`

**When to use:** You found the right past state and want to return to it, recovering from complex mistakes.

📚 **See detailed docs:** `restoring-operations.md`

### 4. Common Patterns & References

Operation references (@, @-), common workflows, best practices.

**When to use:** You need quick reference or want to learn common patterns.

📚 **See detailed docs:** `operation-patterns.md`

## Quick Command Reference

### Viewing

```bash
jj op log                  # Show operation history
jj op show <op-id>         # Show operation details
jj op diff --from <a> --to <b>  # Compare operations
```

### Time Travel (read-only)

```bash
jj log --at-op=<op-id>     # View commit history at operation
jj status --at-op=<op-id>  # View working copy at operation
```

### Restoring

```bash
jj op restore <op-id>      # Jump to specific operation
jj op restore @-           # Go back one operation (= jj undo)
```

## Integration with Undo

**Relationship:** Operation log is the foundation, undo is a convenience.

- `jj undo` = `jj op restore @-` (restore to parent operation)
- `jj undo` twice = `jj op restore @--` (go back 2 operations)

**When to choose each:**

- Quick recent mistake → `jj undo` (see jj-undo skill)
- Need to skip multiple operations → `jj op restore`
- Not sure which operation → Explore with `--at-op`, then restore

## Progressive Disclosure

This skill uses progressive disclosure to manage context efficiently:

1. **Start here** for overview and quick reference
2. **Read detailed docs** when you need specific guidance:
   - `viewing-operations.md` - How to browse and understand operation log
   - `time-travel.md` - How to explore past states without changing anything
   - `restoring-operations.md` - How to restore to past operations and recover
   - `operation-patterns.md` - Common patterns, references, and best practices

Claude will automatically load the relevant detailed documentation when helping you with specific operation log tasks.

## Remember

**Operation log is your time machine.** Everything is recorded, everything is explorable, everything is restorable. You can't lose work in jj.
