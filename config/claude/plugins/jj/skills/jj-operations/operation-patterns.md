# Operation Patterns and References

This document covers operation references, common patterns, and best practices for working with the operation log.

## Operation References

### Symbolic References

**Current operation:** `@`

```bash
jj op show @               # Show current operation
```

**Parent operations:** `@-` (immediate parent), `@--` (grandparent)

```bash
jj op show @-              # Previous operation
jj op restore @-           # Go back one operation (like jj undo)
jj op restore @--          # Go back two operations
jj op restore @----        # Go back 4 operations
```

**Note:** No child operation syntax (`@+`) because operations form a tree, not a line.

### Using References in Commands

```bash
# Show operations
jj op show @               # Current
jj op show @-              # Previous
jj op show @--             # Two back

# Restore operations
jj op restore @-           # = jj undo
jj op restore @---         # Go back 3 operations

# Compare operations
jj op diff --from @--- --to @
```

## Common Patterns

### Pattern: "What Did I Just Do?"

See recent operations and current operation details:

```bash
jj op log --limit 5        # Recent operations
jj op show @               # Current operation details
```

### Pattern: "Find When Things Broke"

Bisect through time to find when things went wrong:

```bash
jj op log                  # Browse operations
# Bisect through time with --at-op
jj log --at-op=<candidate>
# Find last good state, restore to it
```

### Pattern: "Compare Now vs Then"

See all changes between a past operation and now:

```bash
jj op log                  # Find old operation
jj op diff --from <old> --to @  # See all changes
```

### Pattern: "Undo Multiple Operations"

Two approaches to go back several operations:

```bash
# Option 1: Multiple undo
jj undo
jj undo
jj undo

# Option 2: Direct restore (faster)
jj op log
jj op restore @---         # Go back 3 operations
```

### Pattern: "Explore Before Committing"

Use time travel to explore safely before restoring:

```bash
# 1. Browse operations
jj op log

# 2. Explore candidates with --at-op
jj log --at-op=abc123      # Candidate 1
jj log --at-op=def456      # Candidate 2
jj log --at-op=ghi789      # Found it!

# 3. Now commit to the restore
jj op restore ghi789
```

### Pattern: "See What Changed Between Two Operations"

Compare repository state between any two operations:

```bash
jj op log                  # Find two operations of interest
jj op diff --from abc123 --to def456
```

## Best Practices

### When to Use Operation Log

**Use operation log when:**

- ✅ You need to understand what you've been doing
- ✅ You want to find a specific past state
- ✅ You need to recover from complex mistakes
- ✅ You're debugging unexpected repository state
- ✅ You want to see history of changes to a commit

**Don't use operation log when:**

- ❌ You just need to undo the last operation (use `jj undo`)
- ❌ You're looking at commit history (use `jj log`)
- ❌ You want to see file changes (use `jj diff`)

### Exploration First, Restore Second

**Best practice:** Use `--at-op` to explore before using `jj op restore`:

```bash
# ✅ Good: Explore first
jj log --at-op=abc123      # Check if this is right
jj op restore abc123       # Commit to it

# ❌ Risky: Restore without checking
jj op restore abc123       # Hope this is right!
```

### Use Operation References for Recent Operations

For recent operations, use symbolic references instead of IDs:

```bash
# ✅ Good: Clear and concise
jj op restore @-           # Go back one
jj op restore @--          # Go back two

# ❌ Verbose: Looking up IDs
jj op log                  # Find ID
jj op restore abc123def456 # Use ID
```

### Check Status After Restore

Always verify state after restoring:

```bash
jj op restore abc123
jj status                  # Check working copy
jj log                     # Check commit history
```

## Integration with Other Workflows

### With jj-undo Skill

**Relationship:** Operation log is the foundation, undo is a convenience.

```bash
# These are equivalent:
jj undo                    # Simple
jj op restore @-           # Explicit

# These are equivalent:
jj undo && jj undo         # Multiple undo
jj op restore @--          # Direct restore
```

**When to choose each:**

- Quick recent mistake → `jj undo`
- Need to skip multiple operations → `jj op restore`
- Not sure which operation → Explore with `--at-op`, then restore

### With Stack-Based Workflow

Use operation log to recover from stacking mistakes:

```bash
jj new                     # Start new commit
jj describe -m "message"   # Oops, not ready
jj op log                  # Find operation before jj new
jj op restore @--          # Go back before new
```

### With Plan-Driven Workflow

Use operation log to recover plan commits:

```bash
jj describe -m "impl: feature"  # Oops, lost the plan
jj op log                       # Find operation with plan
jj op restore abc123            # Restore plan commit
```

## Quick Reference Card

### Viewing Operations

```bash
jj op log                  # Show operation history
jj op log --limit 20       # Last 20 operations
jj op show <op-id>         # Show operation details
jj op show @               # Show current operation
jj op diff --from <a> --to <b>  # Compare operations
```

### Time Travel (Read-Only)

```bash
jj log --at-op=<op-id>     # View commit history at operation
jj status --at-op=<op-id>  # View working copy at operation
jj diff --at-op=<op-id>    # View changes at operation
```

### Restoring

```bash
jj op restore <op-id>      # Jump to specific operation
jj op restore @-           # Go back one (= jj undo)
jj op restore @--          # Go back two operations
jj op restore @---         # Go back three operations
```

### Operation References

```bash
@                          # Current operation
@-                         # Previous operation
@--                        # Two operations ago
@---                       # Three operations ago
```

## Remember

**Operation log is your time machine:**

- Everything is recorded
- Everything is explorable
- Everything is restorable
- You can't lose work in jj

**Progressive approach:**

1. View operations with `jj op log`
2. Explore safely with `--at-op`
3. Restore confidently with `jj op restore`
4. Verify with `jj status` and `jj log`
