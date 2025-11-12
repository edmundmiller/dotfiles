---
name: Understanding Jujutsu Merges and Conflicts
description: Understand how merge commits work in jj, why they appear empty, how to revert merges, and handle divergent changes. Use when working with merge commits, reverting merged changes, or encountering divergent commits and bookmarks.
allowed-tools: Bash(jj merge:*), Bash(jj new:*), Bash(jj restore:*), Bash(jj log:*), Bash(jj bookmark:*), Bash(jj rebase:*), Read(*/jj-merges-and-conflicts/*.md)
---

# Understanding Jujutsu Merges and Conflicts

## Overview

**Key insights:**
- Jujutsu is **snapshot-based**, not diff-based like Git
- Merge commits calculate changes relative to **auto-merged parents**
- Clean merges with no manual resolution appear **(empty)**
- Conflicts are stored **in commits**, not just working directory
- Divergent changes create multiple heads that need resolution

## Core Concepts

### Why Merge Commits Appear Empty

**The jj model:**

```bash
# Create merge
jj merge parent1 parent2
jj log

# Output shows:
◆  (empty) Merge commits
├─╮
│ ◆ parent2
◆ │ parent1
```

**Why "(empty)"?**

Jj calculates merge changes as:
```
merge_changes = merge_result - auto_merge(parent1, parent2)
```

If auto-merge has no conflicts and you made no manual changes:
```
merge_changes = auto_merge - auto_merge = ∅ (empty)
```

**This is normal and correct!** Empty merge means clean, conflict-free merge.

### Merges with Content

**When merge is NOT empty:**

1. **Manual conflict resolution:**
   ```bash
   jj merge parent1 parent2
   # Conflicts exist
   # Resolve conflicts manually
   # Merge now contains resolution changes
   ```

2. **Additional changes in merge commit:**
   ```bash
   jj merge parent1 parent2
   # Make changes beyond conflict resolution
   echo "extra" >> file.rs
   # Merge now has content
   ```

### Understanding Merge Commits

**In Git:**
```
merge_commit_diff = parent2 - parent1
```
Shows what parent2 added.

**In Jujutsu:**
```
merge_commit_diff = merge_result - auto_merge(parent1, parent2)
```
Shows what YOU added during merge (conflict resolution + manual changes).

**Example:**
```bash
# View merge commit
jj show <merge-commit>

# If empty: clean auto-merge, no manual changes
# If has changes: manual conflict resolution or additional edits
```

## Reverting Merges

**Problem:** Need to undo a merge commit.

**Solution:** Create new commit restoring first-parent state.

```bash
# Current state:
# @  : some work after merge
# │
# ◆  : merge commit (let's call it MERGE)
# ├─╮
# │ ◆ : second-parent
# ◆ │ : first-parent

# Revert the merge
jj new MERGE                    # Create new commit on merge
jj restore --from MERGE^1       # Restore to first parent (^1)

# Or in one step
jj new MERGE
jj restore --from 'MERGE-'      # Restore to first parent
```

**This undoes changes from second parent** while keeping first parent's state.

**Alternative - revert specific changes:**
```bash
# Revert only certain files from merge
jj new MERGE
jj restore --from MERGE^1 path/to/file.rs
```

## Handling Divergent Changes

**What is divergence?**

When the same change ID points to multiple commits (due to concurrent edits or rewrites), jj marks it as divergent.

**Common causes:**
- Concurrent operations in different workspaces
- Bookmark conflicts from fetch
- Manual commit creation with same change ID

**Detecting divergence:**
```bash
# Check for divergent changes
jj log -r 'divergent()'

# Check specific change
jj log -r <change-id>
# Shows multiple commits if divergent
```

**Resolving divergent changes:**

See detailed guide in FAQ reference: `faq-reference.md`

## Resolving Conflicted Bookmarks

**What are conflicted bookmarks?**

When local and remote bookmarks point to different commits after fetch.

**Detecting:**
```bash
# List bookmarks
jj bookmark list

# Conflicted bookmarks shown with special marking
# Example: main@origin, main (local) point to different commits
```

**Resolution:**
```bash
# Choose which commit bookmark should point to
jj bookmark move <bookmark-name> --to <commit-id>

# Common pattern: move to local version
jj bookmark move main --to main

# Or move to remote version
jj bookmark move main --to main@origin
```

**If commits aren't visible:**
```bash
# See all commits including hidden
jj log -r 'all()'

# Find the right commit ID
jj bookmark list  # Shows commit IDs for conflicted bookmarks

# Move bookmark
jj bookmark move main --to <commit-id>
```

## When to Use This Skill

Use this skill when:
- ✅ Merge commits showing as "(empty)"
- ✅ Need to revert a merge
- ✅ Encountering divergent changes
- ✅ Resolving conflicted bookmarks
- ✅ Understanding merge semantics
- ✅ Dealing with concurrent modifications

Don't use this skill for:
- ❌ Regular conflict resolution (basic jj workflow)
- ❌ Rebasing commits (jj-workflow skill)
- ❌ Bookmark management (jj-bookmarks-and-remotes skill)

## Progressive Disclosure

For detailed FAQ answers and conflict resolution strategies:

📚 **See detailed docs:** `faq-reference.md`

This includes:
- Complete FAQ answers about merges
- Detailed divergence resolution
- Advanced merge patterns
- Conflict resolution strategies
- Bookmark conflict details

## Quick Reference

```bash
# Creating merges
jj merge <commit1> <commit2>       # Create merge commit
jj new <commit1> <commit2>         # Same as merge

# Viewing merges
jj show <merge-commit>             # Show merge changes
jj log -r 'merges()'              # List all merge commits

# Reverting merges
jj new <merge-commit>
jj restore --from '<merge-commit>-'  # Restore to first parent

# Divergence
jj log -r 'divergent()'           # Show divergent changes
jj log -r <change-id>             # See all commits with change ID

# Bookmark conflicts
jj bookmark list                   # Show bookmarks (conflicts marked)
jj bookmark move <name> --to <id> # Resolve conflict
jj log -r 'all()'                 # See hidden commits
```

## Remember

**Empty merges are normal.** They mean jj auto-merged successfully without conflicts. The merge commit only contains changes YOU made (conflict resolution or additional edits), not the combination of both parents.
