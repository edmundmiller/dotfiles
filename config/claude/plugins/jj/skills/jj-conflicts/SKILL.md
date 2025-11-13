---
name: jj-conflicts
description: Help users identify, understand, and resolve conflicts in jj repositories. Use when user mentions 'conflict', 'resolve conflicts', 'merge conflict', 'conflicted commits', '2-sided conflict', or encounters conflict-related errors.
allowed-tools:
  - Bash(jj status:*)
  - Bash(jj log -r 'conflicts()':*)
  - Bash(jj resolve:*)
  - Bash(jj restore:*)
  - Bash(jj diff:*)
  - Bash(jj edit:*)
---

# Jj Conflict Resolution

This skill helps you identify and resolve conflicts in jj repositories, with special emphasis on safely using `jj restore` with path specifications.

## Understanding Jj Conflicts

### How Jj Differs from Git

- **Git**: Conflicts block operations; you must resolve before continuing
- **Jj**: Conflicts are stored in commits; you can continue working and resolve later

When jj encounters a conflict, it:

1. Marks the commit with a conflict indicator (× in `jj log`)
2. Stores conflict markers in the affected files
3. Allows you to continue working on descendants

### Types of Conflicts

**"2-sided conflict"**: Two versions of the same content that can't be automatically merged

**"2-sided conflict including 1 deletion"**: One side deleted a file/content, the other modified it

- Common when adding files to `.gitignore` after they were already tracked
- One of the most frequent conflict scenarios

## Identifying Conflicts

### Find All Conflicted Commits

```bash
jj log -r 'conflicts()'
```

This shows all commits with unresolved conflicts. Look for the × marker.

### Check Current Status

```bash
jj status
```

If you're in a conflicted commit, this will show:

```
Warning: There are unresolved conflicts at these paths:
.obsidian/workspace.json    2-sided conflict including 1 deletion
```

### Inspect Specific Conflict

```bash
jj edit <conflicted-commit-id>
jj diff
```

## Resolution Strategies

### Strategy A: Using jj resolve (Recommended for Most Cases)

The `jj resolve` command is purpose-built for conflict resolution:

```bash
# Navigate to conflicted commit
jj edit <commit-id>

# List all conflicts
jj resolve --list

# Accept parent's version (side 1) - "ours"
jj resolve --tool :ours <path>

# Accept child's version (side 2) - "theirs"
jj resolve --tool :theirs <path>

# Use interactive merge tool (if configured)
jj resolve <path>
```

**When to use:**

- Most conflict scenarios
- When you want semantic clarity (`:ours` vs `:theirs`)
- When working with merge tools

### Strategy B: Using jj restore (Safe When Paths Specified)

The `jj restore` command can restore files from any commit:

```bash
# Navigate to conflicted commit
jj edit <commit-id>

# Restore SPECIFIC path from parent
jj restore --from @- <path>
```

**When to use:**

- Accepting parent's version for specific files
- When you want more control over the source (`--from` can be any revision)
- For deletion conflicts (equivalent to `:ours` in resolve)

### ⚠️ CRITICAL: The Path Argument

This is the **most important safety rule** when using `jj restore`:

```bash
# ❌ DANGEROUS - Restores ALL files from parent
#    This will LOSE ALL CHANGES in the current commit!
jj restore --from @-

# ✅ SAFE - Restores ONLY the specified path
#    All other changes in the commit are preserved
jj restore --from @- .obsidian/
jj restore --from @- src/config.rs
```

**Why this matters:**

- Without a path argument, `jj restore` operates on ALL files
- With a path argument, it operates ONLY on that specific path
- The difference between preserving your work and losing it entirely

### Strategy C: Manual Editing

For complex conflicts, you can edit the conflict markers directly:

```bash
jj edit <commit-id>
# Edit files with conflict markers
# Remove markers and keep desired content
jj diff  # Verify your resolution
```

Conflict markers look like:

```
<<<<<<<
Content from side 1 (parent)
%%%%%%%
Common ancestor content
+++++++
Content from side 2 (child)
>>>>>>>
```

### Strategy D: New Commit Then Squash (Jj's Recommended Pattern)

For complex resolutions, jj recommends creating a resolution commit:

```bash
# Create new commit on top of conflicted one
jj new <conflicted-commit-id>

# Resolve using any method above
jj resolve --tool :ours <path>

# Review the resolution
jj diff

# Squash resolution back into parent
jj squash
```

**Benefits:**

- Separates resolution from original changes
- Easy to review resolution before committing
- Can undo resolution easily

## Common Conflict Scenarios

### Scenario 1: Parent Deleted, Child Modified

**Situation:** Parent commit deleted files (e.g., added to `.gitignore`), but child commits still have changes to those files.

**Example:** You added `.obsidian/` to `.gitignore` and untracked it in commit `oo`, but 13 descendant commits still had `.obsidian/` changes.

**Conflict message:**

```
.obsidian/workspace.json    2-sided conflict including 1 deletion
```

**Resolution:** Accept the deletion by restoring from parent

```bash
# Method 1: Using jj resolve (more semantic)
jj edit <conflicted-commit>
jj resolve --tool :ours .obsidian/

# Method 2: Using jj restore (equally correct)
jj edit <conflicted-commit>
jj restore --from @- .obsidian/
```

**For multiple commits:**

```bash
# Process each conflicted commit
for commit in $(jj log -r 'conflicts()' --no-graph -T 'change_id.short(4)'); do
  jj edit "$commit"
  jj restore --from @- .obsidian/
done
```

### Scenario 2: Both Sides Modified Same Content

**Situation:** Both parent and child modified the same lines in a file.

**Resolution options:**

1. Accept one side: `jj resolve --tool :ours` or `:theirs`
2. Merge manually: Edit conflict markers
3. Use merge tool: `jj resolve <path>` (if configured)

### Scenario 3: Rename Conflicts

**Situation:** One side renamed a file, the other modified it.

**Resolution:** Choose which version to keep, potentially applying changes from other side manually.

## Key Differences: jj restore vs jj resolve

| Aspect               | jj resolve                        | jj restore --from @- <path>                 |
| -------------------- | --------------------------------- | ------------------------------------------- |
| **Purpose**          | Conflict resolution               | Generic file restoration                    |
| **Semantic clarity** | `:ours`/`:theirs` explicit        | Less explicit (must know parent/child)      |
| **Merge tools**      | Supported                         | Not supported                               |
| **Flexibility**      | Limited to conflict resolution    | Can restore from any revision               |
| **Safety**           | Only operates on conflicted files | **MUST specify paths** or affects all files |

**Both are correct for accepting deletions, but resolve is more semantically clear.**

## Safety Checklist

Before resolving conflicts:

- ✅ **Always specify path arguments** when using `jj restore --from`
- ✅ **Use `jj diff` to verify changes** before and after resolution
- ✅ **Test resolution** with one commit before batch processing
- ✅ **Check `jj status`** to confirm conflict is resolved
- ❌ **Never use `jj restore --from @-` without paths** unless you intend to reset entire commit

## Real-World Example: Untracking Previously-Committed Files

This documents a real scenario that illustrates the critical importance of path specification:

### The Situation

1. You added `.obsidian/` to `.gitignore` in commit `oo`
2. You untracked `.obsidian/` files in that commit: `jj file untrack .obsidian/`
3. 13 descendant commits still contained `.obsidian/` changes
4. After rebasing: `jj rebase -r 'oo..@' -d oo`
5. Result: All 13 descendant commits now have conflicts

### The Conflicts

Each conflict shows:

```
.obsidian/workspace.json    2-sided conflict including 1 deletion
```

This means:

- Parent (commit `oo`): Deleted `.obsidian/` files
- Child commits: Still have changes to `.obsidian/` files

### The Wrong Approach (What NOT to Do)

```bash
# ❌ WRONG - This was tried first
jj edit <commit-id>
jj restore --from @-  # No path specified!

# Result: ALL files restored from parent
# - All task files: DELETED
- All document changes: LOST
# - Only .obsidian/ should have been affected, but EVERYTHING was reset
```

**Why this failed:** Without a path argument, `jj restore --from @-` restores **every file** from the parent, effectively undoing all changes in the commit.

### The Correct Solution

```bash
# ✅ CORRECT - Specify the path
jj edit <commit-id>
jj restore --from @- .obsidian/  # Path specified!

# Result: Only .obsidian/ restored from parent
# - Task files: PRESERVED ✓
# - Document changes: PRESERVED ✓
# - .obsidian/ conflicts: RESOLVED ✓
```

**Or using jj resolve (more semantic):**

```bash
jj edit <commit-id>
jj resolve --tool :ours .obsidian/
```

### Processing All Conflicts

```bash
# Get list of conflicted commits
jj log -r 'conflicts()'

# Process each one with PATHS SPECIFIED
for commit in oymp zzyv knzl xlxr lutt xznz uvnk zosw vzxv utmq xtsk qvot pqnr; do
  echo "Resolving $commit"
  jj edit "$commit"
  jj restore --from @- .obsidian/  # ← The critical path argument
done

# Verify all conflicts resolved
jj log -r 'conflicts()'  # Should return empty
```

### Key Takeaway

The difference between these two commands is **losing all your work** vs **safely resolving conflicts**:

```bash
jj restore --from @-             # ← Danger: ALL files
jj restore --from @- .obsidian/  # ← Safe: ONLY specified path
```

**Always specify the path when resolving conflicts with `jj restore`.**

## Quick Reference

### Find conflicts

```bash
jj log -r 'conflicts()'
jj status
```

### Resolve with jj resolve

```bash
jj edit <commit-id>
jj resolve --tool :ours <path>    # Accept parent's version
jj resolve --tool :theirs <path>  # Accept child's version
```

### Resolve with jj restore (MUST SPECIFY PATH)

```bash
jj edit <commit-id>
jj restore --from @- <path>  # Accept parent's version for PATH ONLY
```

### Verify resolution

```bash
jj diff
jj status
jj log -r 'conflicts()'  # Should not include current commit
```

## Integration with Other Workflows

### After Rebase

Rebasing often creates conflicts:

```bash
jj rebase -r <commits> -d <destination>
# Check for new conflicts
jj log -r 'conflicts()'
# Resolve as needed
```

### Before Push

Always resolve conflicts before pushing:

```bash
# Check for unresolved conflicts
jj log -r 'conflicts() & mine()'

# If any found, resolve them first
# Then proceed with push
```

### With jj-spr

Conflicts can appear when updating stacked PRs:

```bash
jj rebase -d main
# Resolve any conflicts
jj restore --from @- <conflicted-path>
# Update PRs
jj spr update
```

## When to Use This Skill

Invoke this skill when you encounter:

- "There are unresolved conflicts at these paths"
- × markers in `jj log` output
- "2-sided conflict" messages
- Questions about using `jj restore` safely
- Need to accept parent's or child's version in conflicts
- Rebase operations that create conflicts
- Files that were added to `.gitignore` after being tracked
