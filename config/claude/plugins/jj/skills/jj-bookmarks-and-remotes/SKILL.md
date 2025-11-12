---
name: Understanding Jujutsu Bookmarks and Remotes
description: Understand how bookmarks work in jj, why they don't auto-move, and how to push changes to git remotes. Use when bookmarks don't move after jj new/commit, when push says "Nothing changed", or when working with git remotes.
allowed-tools: Bash(jj bookmark:*), Bash(jj git push:*), Bash(jj log:*), Bash(jj status:*), Read(*/jj-bookmarks-and-remotes/*.md)
---

# Understanding Jujutsu Bookmarks and Remotes

## Overview

**Key insight:** Jujutsu lacks a "current bookmark" concept. Unlike Git where the current branch automatically moves with commits, jj bookmarks stay where you put them until explicitly moved.

This is the most common source of confusion for Git users switching to jj.

## Core Concepts

### Bookmarks Don't Auto-Move

**The problem:**
```bash
jj new -m "my change"
jj bookmark list  # Your bookmark is still on the old commit!
```

**Why:** Jujutsu doesn't have a "current bookmark" like Git's HEAD. Bookmarks are just pointers you manually control.

**Solution:**
```bash
jj bookmark move <bookmark-name>  # Move to current commit (@)
jj bookmark set <bookmark-name>   # Create or move bookmark
```

### Pushing Changes to Git Remotes

**The problem:**
```bash
jj git push --all
# Output: "Nothing changed."
```

**Why:** `jj git push` pushes bookmarks, not revisions. Your new commit doesn't have a bookmark pointing to it.

**Solutions:**

1. **Auto-create bookmark** (easiest):
   ```bash
   jj git push --change <change-id>  # Creates bookmark automatically
   ```

2. **Manual bookmark management** (explicit):
   ```bash
   jj bookmark set my-feature        # Create/move bookmark to @
   jj git push --bookmark my-feature # Push specific bookmark
   ```

3. **Push all bookmarks**:
   ```bash
   jj bookmark set feature-1
   jj bookmark set feature-2
   jj git push --all                 # Pushes all bookmarks
   ```

## Common Workflows

### Creating a Feature Branch

```bash
# 1. Create changes
jj new -m "implement feature"
# ... make your changes ...

# 2. Attach a bookmark
jj bookmark set my-feature

# 3. Push to remote
jj git push --bookmark my-feature
```

### Working with Existing Bookmarks

```bash
# See all bookmarks
jj bookmark list

# Move bookmark to current commit
jj bookmark move main

# Move bookmark to specific commit
jj bookmark move main --to <revision>

# Delete local bookmark
jj bookmark delete old-feature

# Push deletion to remote
jj git push --bookmark old-feature --delete
```

## When to Use This Skill

Use this skill when:
- ✅ Your bookmark doesn't move after `jj new` or `jj commit`
- ✅ `jj git push --all` says "Nothing changed"
- ✅ You need to push changes to a git remote
- ✅ You're managing feature branches
- ✅ You're debugging bookmark-related issues

Don't use this skill for:
- ❌ Commit organization (see commit-curation skill)
- ❌ Operation history (see jj-operations skill)
- ❌ General workflow (see jj-workflow skill)

## Progressive Disclosure

For detailed FAQ answers and troubleshooting:

📚 **See detailed docs:** `faq-reference.md`

This includes:
- Complete FAQ answers for bookmark questions
- Advanced bookmark manipulation
- Troubleshooting push issues
- Git interop edge cases

## Quick Reference

```bash
# Bookmark management
jj bookmark list                      # List all bookmarks
jj bookmark set <name>                # Create/move to current commit
jj bookmark move <name>               # Move to current commit
jj bookmark move <name> --to <rev>   # Move to specific commit
jj bookmark delete <name>             # Delete bookmark

# Pushing to remotes
jj git push --change <change-id>      # Auto-create bookmark and push
jj git push --bookmark <name>         # Push specific bookmark
jj git push --all                     # Push all bookmarks
jj git push --bookmark <name> --delete # Delete remote bookmark
```

## Remember

**Bookmarks are manual pointers.** They don't move automatically. Think of them as sticky notes you move yourself, not as Git's auto-following branches.
