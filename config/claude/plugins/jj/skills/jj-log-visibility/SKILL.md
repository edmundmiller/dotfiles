---
name: Understanding Jujutsu Log and Visibility
description: Understand what commits are visible in jj log, elided revisions, and how to display different views. Use when commits seem missing, understanding log output, comparing jj log to git log, or seeing "elided" in log output.
allowed-tools: Bash(jj log:*), Bash(jj status:*), Bash(jj evolog:*), Read(*/jj-log-visibility/*.md)
---

# Understanding Jujutsu Log and Visibility

## Overview

**Key insight:** `jj log` doesn't show all commits by default. It shows a smart subset: local commits and their parents. This prevents overwhelming you with the entire repository history.

Understanding visibility rules is essential for finding commits and understanding jj's output.

## Core Concepts

### Default Visibility

**What you see by default:**
```bash
jj log  # Shows: local commits + their parents
```

This includes:
- Commits you created locally
- Parents of your commits (for context)
- Commits reachable from your working copy (`@`)

**What's hidden:**
- Remote commits you haven't based work on
- Abandoned commits
- Commits marked as hidden

### Seeing All Commits

```bash
# See everything, including hidden commits
jj log -r 'all()'

# See all visible commits (excluding root)
jj log -r '..'

# See commits matching git log
jj log -r '..'  # Similar to: git log --all
```

### Elided Revisions

**What are they?**

When jj log shows: `◆  <several revisions>`, it means intermediate commits exist but aren't shown in the current view.

**Example:**
```
@  abc123 my work
│  <several revisions>  ← Elided!
◆  def456 base commit
```

This means commits exist between `abc123` and `def456`, but they're not displayed.

**Showing elided commits:**
```bash
# Show connecting commits
jj log -r 'connected(abc123, def456)'

# Show all ancestors
jj log -r 'ancestors(abc123, 10)'  # Show 10 levels

# Show everything between
jj log -r 'abc123..def456'
```

## Common Use Cases

### Finding a "Missing" Commit

**Problem:** Made a commit but don't see it in `jj log`.

**Solutions:**

1. **Check visibility:**
   ```bash
   jj log -r 'all()'  # See if it's hidden
   ```

2. **Search by description:**
   ```bash
   jj log -r 'description(keyword)'
   ```

3. **Search by author:**
   ```bash
   jj log -r 'author(your-name)'
   ```

4. **Make it visible again:**
   ```bash
   jj new <commit-id>  # Creates child, makes commit visible
   ```

### Comparing to Git Log

**Git behavior:**
```bash
git log            # Shows current branch history
git log --all      # Shows all refs/branches
```

**Jj equivalents:**
```bash
jj log -r '@-'     # Show current lineage (like git log)
jj log -r '..'     # Show all visible (like git log --all)
jj log -r 'all()'  # Show absolutely everything
```

### Monitoring Log Changes

**Problem:** Want to watch log evolve as you work.

**Solutions:**

```bash
# Using watch (Linux/macOS)
watch -n 1 jj log

# Using hwatch (better formatting)
hwatch -n 1 jj log

# Using viddy (interactive)
viddy jj log

# Using watchexec (watches for file changes)
watchexec -w .jj/repo/op_heads/heads jj log
```

**Pro tip:** Consider `jj-fzf` or check the wiki for TUIs/GUIs.

## Revset Patterns for Visibility

```bash
# Local work only
jj log -r 'mine()'

# Everything reachable from @
jj log -r 'ancestors(@)'

# Recent work (last 10 commits)
jj log -r 'ancestors(@, 10)'

# Commits since yesterday
jj log -r 'after(yesterday)'

# Commits matching pattern
jj log -r 'description(fix)'
jj log -r 'author(alice)'

# Commits with bookmarks
jj log -r 'bookmarks()'

# Commits without description
jj log -r 'description(exact:"")'
```

## When to Use This Skill

Use this skill when:
- ✅ Commits seem to be missing from `jj log`
- ✅ You see "elided revisions" and want to show them
- ✅ You're comparing jj log behavior to git log
- ✅ You need to find hidden or abandoned commits
- ✅ You want to monitor log output over time

Don't use this skill for:
- ❌ Operation history (see jj-operations skill)
- ❌ Working copy history (see jj-working-copy-snapshots skill)
- ❌ General workflow (see jj-workflow skill)

## Progressive Disclosure

For detailed FAQ answers and advanced revset patterns:

📚 **See detailed docs:** `faq-reference.md`

This includes:
- Complete FAQ answers for visibility questions
- Advanced revset patterns
- Troubleshooting missing commits
- Detailed comparison with git log
- Monitoring and automation patterns

## Quick Reference

```bash
# Visibility control
jj log                    # Default view (local + parents)
jj log -r 'all()'        # Everything including hidden
jj log -r '..'           # All visible commits (git log --all equivalent)
jj log -r 'ancestors(@)' # Commits leading to @

# Finding commits
jj log -r 'description(text)'  # Search descriptions
jj log -r 'author(name)'       # Search by author
jj log -r 'mine()'             # Your commits

# Elided revisions
jj log -r 'connected(a, b)'    # Show connecting commits
jj log -r 'ancestors(@, 10)'   # Last 10 ancestors
```

## Remember

**Visibility is intentional.** Jj hides commits to reduce noise, not because they're lost. Use `jj log -r 'all()'` to see everything, or refine your revset to find specific commits.
