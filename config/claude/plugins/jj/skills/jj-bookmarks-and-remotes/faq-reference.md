# Bookmarks and Remotes - Detailed FAQ

## Q: Why doesn't my bookmark move to the new commit after `jj new/commit`?

**Answer:** Jujutsu lacks a "current bookmark" concept that Git has. In Git, the current branch automatically moves when you create a commit. In jj, bookmarks are independent pointers that stay where you put them.

**Mental model shift:**
- **Git:** Branch is "attached" to HEAD and moves with you
- **Jujutsu:** Bookmarks are "sticky notes" you manually place on commits

**Solution:** Use `jj bookmark move` to reposition bookmarks manually.

```bash
# After making changes
jj new -m "my feature"

# Bookmark is still on the old commit, so move it
jj bookmark move feature-branch

# Or in one step when creating
jj new -m "my feature" && jj bookmark set feature-branch
```

**Why jj works this way:**
- Allows multiple bookmarks per commit without ambiguity
- Makes it explicit where bookmarks point
- Prevents accidental bookmark movement
- Supports stacked changes without bookmark gymnastics

## Q: I made a commit but `jj git push --all` says "Nothing changed." What should I do?

**Answer:** The command pushes bookmarks, not revisions. Your new commit likely doesn't have a bookmark pointing to it.

**Understanding `jj git push`:**
- `jj git push` syncs **bookmarks** to the remote
- It doesn't push "commits" - it pushes bookmark positions
- If a commit has no bookmark, it won't be pushed

**Solutions:**

### Option 1: Auto-create bookmark (recommended)

```bash
jj git push --change <change-id>
```

This automatically creates a temporary bookmark, pushes it, and can be used for pull requests.

**When to use:** Quick pushes, creating PRs, one-off shares.

### Option 2: Manual bookmark management

```bash
jj bookmark set my-feature  # Create/move bookmark to current commit (@)
jj git push --bookmark my-feature
```

**When to use:** Long-lived branches, multiple features, explicit control.

### Option 3: Push all bookmarks

```bash
jj bookmark set feature-1  # Ensure bookmarks point to your commits
jj bookmark set feature-2
jj git push --all          # Push all bookmarks
```

**When to use:** Multiple features ready to push, sync everything.

## Advanced Bookmark Operations

### Moving bookmarks to specific commits

```bash
# Move to a specific revision
jj bookmark move main --to <revision>

# Move to parent of current
jj bookmark move main --to @-

# Move to a change by description
jj bookmark move main --to 'description(fix bug)'
```

### Resolving conflicted bookmarks

When bookmarks diverge (local and remote point to different commits), jj marks them as conflicted.

```bash
# Check for conflicts
jj bookmark list

# Resolve by choosing a commit
jj bookmark move <name> --to <commit-id>

# If commits aren't visible in log
jj log -r 'all()'  # See all commits including hidden ones
jj bookmark move <name> --to <commit-id>
```

### Working with remote-tracking bookmarks

```bash
# See remote bookmarks
jj bookmark list --all

# Track remote bookmark locally
jj bookmark track <remote-name>@origin

# Stop tracking remote bookmark
jj bookmark untrack <bookmark-name>@origin
```

## Git Interop Patterns

### Creating a feature branch for PR

```bash
# Start from main
jj new 'main'
jj describe -m "implement feature X"

# Make your changes...

# Create bookmark and push
jj bookmark set feature-x
jj git push --bookmark feature-x

# Or use --change for auto-bookmark
jj git push --change @
```

### Updating an existing PR

```bash
# Make more changes to current commit
jj describe -m "updated implementation"

# Push bookmark (it's already set)
jj git push --bookmark feature-x

# Or if bookmark moved, force push
jj git push --bookmark feature-x --force
```

### Syncing with upstream

```bash
# Fetch from remote
jj git fetch

# See what changed
jj log -r 'main'

# Rebase your work onto updated main
jj rebase -d main
```

## Common Mistakes

### Mistake 1: Expecting Git behavior

```bash
# ❌ This won't work like Git
jj new -m "feature"
jj git push  # Bookmark didn't move!

# ✅ Explicitly manage bookmarks
jj new -m "feature"
jj bookmark set my-feature
jj git push --bookmark my-feature
```

### Mistake 2: Forgetting to set bookmarks before push

```bash
# ❌ Creates commits without bookmarks
jj new -m "feature 1"
jj new -m "feature 2"
jj git push --all  # Nothing to push!

# ✅ Set bookmarks as you go
jj new -m "feature 1"
jj bookmark set feature-1
jj new -m "feature 2"
jj bookmark set feature-2
jj git push --all  # Pushes both
```

### Mistake 3: Losing track of bookmarks

```bash
# ❌ Bookmark left behind
jj new -m "fix"
jj new -m "another fix"  # bookmark still on first commit

# ✅ Move bookmark forward
jj new -m "fix"
jj bookmark move my-feature
jj new -m "another fix"
jj bookmark move my-feature
```

## Troubleshooting

### "remote rejected" errors

**Problem:** Git remote rejects your push.

**Common causes:**
1. Force push not allowed on branch
2. Branch protection rules
3. No permission to push

**Solutions:**
```bash
# Check what you're trying to push
jj log -r 'bookmark(my-feature)'

# Use --force if allowed
jj git push --bookmark my-feature --force

# Or create new bookmark/branch
jj bookmark set my-feature-v2
jj git push --bookmark my-feature-v2
```

### Bookmarks pointing to wrong commits

**Problem:** Bookmark ended up on unexpected commit.

**Diagnosis:**
```bash
# See where bookmark points
jj log -r 'bookmark(my-feature)'

# See bookmark history
jj op log  # Look for bookmark operations
```

**Fix:**
```bash
# Move to correct commit
jj bookmark move my-feature --to <correct-revision>

# If you need to undo
jj undo  # Undoes the last operation
```

### Can't find bookmark after push

**Problem:** Pushed with `--change` but can't find bookmark.

**Explanation:** `--change` creates temporary bookmark based on change ID.

**Solution:**
```bash
# List all bookmarks including remotes
jj bookmark list --all

# Create permanent local bookmark
jj bookmark set feature-name
jj bookmark move feature-name --to <change-id>
```

## Best Practices

1. **Set bookmarks early:** Create bookmarks when starting features, not before pushing
2. **Use meaningful names:** `fix-auth-bug` not `temp` or `asdf`
3. **Clean up old bookmarks:** Delete merged feature bookmarks
4. **Prefer `--change` for quick shares:** Less bookmark management overhead
5. **Use `--bookmark` for long-lived work:** Explicit control over what's pushed
6. **Keep main bookmark synced:** Regularly `jj bookmark move main` after rebasing

## Reference Commands

```bash
# Bookmark inspection
jj bookmark list                    # Local bookmarks
jj bookmark list --all              # All bookmarks (including remotes)
jj log -r 'bookmarks()'            # Commits with bookmarks
jj log -r 'bookmark(name)'         # Specific bookmark's commit

# Bookmark creation/movement
jj bookmark set <name>              # Create or move to @
jj bookmark move <name>             # Move to @
jj bookmark move <name> --to <rev> # Move to specific commit
jj bookmark delete <name>           # Delete local bookmark

# Remote operations
jj git fetch                        # Fetch from remotes
jj git push --change <id>          # Push with auto-bookmark
jj git push --bookmark <name>      # Push specific bookmark
jj git push --all                   # Push all bookmarks
jj git push --bookmark <name> --delete # Delete remote bookmark
jj bookmark track <name>@<remote>   # Track remote bookmark
```
