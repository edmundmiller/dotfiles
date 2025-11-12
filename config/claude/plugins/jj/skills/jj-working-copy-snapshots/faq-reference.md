# Working Copy Snapshots - Detailed FAQ

## Q: Where can I see the automatic "saves" of my working copy?

**Answer:** Each command updates the working-copy revision marked with `@`. The commit ID changes when amended. Use `jj evolog` to view working copy change history.

**Understanding the mechanism:**

### The Working Copy Commit (`@`)

Every time you run a jj command:
1. **Snapshot:** Working directory is saved as new version of `@`
2. **Update commit ID:** Commit ID changes (but change ID stays same)
3. **Execute:** Command runs
4. **Update files:** Working directory updated if needed

**View snapshots:**

```bash
# See evolution of @
jj evolog

# With patch diffs
jj evolog --patch

# Limit output
jj evolog --limit 10
```

**Example output:**
```
@  wxyz xyz789 (now) implement feature
│
◆  wxyz xyz456 implement feature
│  <snapshot before jj log>
◆  wxyz xyz123 implement feature
   <snapshot before jj status>
```

All have same change ID (`wxyz`) but different commit IDs - showing the evolution.

### Finding Specific Snapshots

**By time:**
```bash
# Last 5 snapshots
jj evolog --limit 5

# See operation that created snapshot
jj op log --limit 10
```

**By content:**
```bash
# See patch for each snapshot
jj evolog --patch | less

# Find snapshot with specific change
jj evolog --patch | grep -B 5 "function_name"
```

**Restore from snapshot:**
```bash
# Find the commit ID you want
jj evolog

# Restore files from that snapshot
jj restore --from <commit-id>
```

## Q: Can I prevent Jujutsu from recording my unfinished work?

**Answer:** Jujutsu auto-records changes by design. Instead of preventing recording, use `jj new` to create intermediate drafts, then `jj squash` to amend previous commits.

**Why auto-recording is good:**
- Can't lose work
- Every state is recoverable
- No "staging" ceremony

**Recommended workflows:**

### Workflow 1: Stack with `jj new`

```bash
# Working on feature
echo "code" > feature.rs

# Not ready to finalize, but want to save progress
jj new  # Creates new empty commit

# Continue working in new commit
echo "more code" > feature2.rs

# Later, squash related work together
jj squash  # Merges @ into @-
```

**When to use:** Frequent saves, experimental work, complex changes.

### Workflow 2: WIP descriptions

```bash
# Mark work as in-progress
jj describe -m "WIP: implementing auth"

# Work on something else
jj new -m "fix bug in parser"

# Return to WIP later
jj edit 'description("WIP: implementing")'
```

**When to use:** Context switching, async work, tracking multiple tasks.

### Workflow 3: Describe when done

```bash
# Work in @ without describing
# Make changes...

# When ready, describe the final state
jj describe -m "implement authentication system"

# Move to next task
jj new
```

**When to use:** Flow state coding, when you know what you're doing.

## Q: Can I create commits from only some working copy changes?

**Answer:** Use `jj split -i` (or `jj commit -i`) to split the working-copy commit interactively, similar to `git add -p`.

**Interactive splitting:**

```bash
# Split @ interactively
jj split -i

# Or use commit (alias for split)
jj commit -i
```

**This opens your diff editor** (configured in `~/.jjconfig.toml`) where you can:
- Select which changes to include
- Leave rest in @
- Create focused commits

**Example flow:**
```bash
# Made changes to multiple files
jj status
# Working copy changes:
# M src/auth.rs
# M src/parser.rs
# M tests/auth_test.rs

# Split interactively
jj split -i
# In editor: select only auth.rs and auth_test.rs changes

# Result:
# @- : contains auth.rs + auth_test.rs changes
# @  : contains parser.rs changes

# Describe each commit
jj describe @- -m "implement authentication"
jj describe -m "improve parser error handling"
```

**Non-interactive splitting:**

```bash
# Split by path pattern
jj split 'glob:tests/**'  # Tests in one commit

# Split by path list
jj split file1.rs file2.rs  # These files in one commit
```

**Workflow for mixed changes:**

1. **Make changes** to multiple files
2. **Split**: `jj split -i` to separate concerns
3. **Describe**: Add commit messages to each piece
4. **Review**: `jj log --patch` to verify separation

## Q: How do I keep scratch files without committing them?

**Answer:** Configure `snapshot.auto-track` to limit auto-tracking. Use `.gitignore` patterns for scratch files, or maintain a separate ignored directory.

### Method 1: Use `.gitignore` (recommended)

```bash
# Add patterns to .gitignore
echo "scratch/" >> .gitignore
echo "*.tmp" >> .gitignore
echo "*.scratch" >> .gitignore
echo "TODO.txt" >> .gitignore

# Commit .gitignore
jj describe -m "add gitignore for scratch files"
```

**Ignored files aren't tracked:**
- New ignored files: not auto-tracked
- Already tracked files: remain tracked (untrack manually)

**Untrack already-tracked files:**
```bash
# Untrack but keep file
jj file untrack scratch.txt

# File stays in working directory but removed from @
```

### Method 2: Configure `snapshot.auto-track`

```toml
# ~/.jjconfig.toml (global) or .jj/repo/config.toml (per-repo)
[snapshot]
auto-track = "none"  # Don't auto-track any new files
```

**With `auto-track = "none"`:**
- New files aren't automatically tracked
- Must explicitly track files: `jj file track <path>`
- Existing tracked files remain tracked

**Track files when needed:**
```bash
# Manually track specific file
jj file track src/feature.rs

# Track all files in directory
jj file track src/**/*.rs
```

**Selective auto-tracking with globs:**

```toml
# Only auto-track source files
[snapshot]
auto-track = "glob:src/**/*.rs"
```

```toml
# Auto-track everything except scratch
[snapshot]
auto-track = "!glob:scratch/**"
```

### Method 3: Separate scratch directory

```bash
# Create scratch directory outside repo
mkdir ~/scratch/myproject

# Keep notes, experiments, temp files there
# They're completely outside jj tracking
```

**When to use each:**

| Method | Use case |
|--------|----------|
| `.gitignore` | Standard scratch files, common patterns |
| `auto-track = "none"` | Strict control, require explicit tracking |
| Glob patterns | Complex rules, mixed tracking needs |
| External directory | Completely separate scratch space |

## Q: How do I avoid committing local-only changes to tracked files?

**Answer:** Keep private changes in a separate commit branched from trunk, then merge it into your working branch. Configure `git.private-commits` to prevent accidental pushes.

**The problem:**

You need local-only changes (debug logging, test credentials, local config) but don't want to commit them to shared branches.

### Solution: Private changes commit

**Setup:**

```bash
# Create commit with private changes from main
jj new main -m "private: local development config"

# Make your local-only changes
echo "DEBUG=true" >> .env
echo "LOCAL_DB=localhost" >> config.toml

# Describe and remember change ID
jj describe -m "private: local development settings"
jj log -r @ --no-graph -T 'change_id'  # Note this
# Example: abc123xyz
```

**Working on features:**

```bash
# Start feature from main
jj new main -m "implement feature X"

# Merge in private changes
jj rebase -d @ -s abc123xyz  # abc123xyz is your private commit
# Or: jj new @ abc123xyz (creates merge commit)

# Now @ has both feature work and private changes
# Work normally...

# When ready to share:
jj new main  # Create commit from main
jj rebase -s <feature-change-id> -d @  # Rebase feature without private

# Or squash feature without private changes
# (requires careful change selection)
```

**Prevent accidental push:**

```toml
# ~/.jjconfig.toml
[git]
private-commits = "description(glob:'private:*')"
```

This prevents pushing commits with "private:" prefix.

**Alternative: Always merge pattern**

```bash
# Keep private commit separate
jj new main -m "private: local config"
# change ID: abc123xyz

# For every feature:
jj new main -m "feature X"
# Make changes to feature

# Create merge commit
jj new @ abc123xyz -m "WIP: feature X + local config"
# This @ has both feature and private changes

# Work in this merged state
# To share feature:
jj new main
jj rebase -s <feature-change> -d @  # Moves just feature changes
```

**Best practices:**

1. **Use "private:" prefix** in descriptions
2. **Configure `git.private-commits`** to prevent push
3. **Keep private changes minimal** (config, not code)
4. **Document private commits** in project README
5. **Use `.gitignore`** when possible instead

## Q: I changed files in the wrong commit. How do I move them?

**Answer:** Four-step process: 1) Find the last good version (check `jj evolog --patch`), 2) Create new empty commit on that version, 3) Restore previous contents, 4) Move bookmarks and abandon the unwanted revision.

**Scenario:** Made changes in `@` that should be in a different commit.

### Solution 1: Move changes with restore

**If changes should be in parent:**

```bash
# Current state:
# @  : has changes that should be in @-
# @- : parent commit

# Create new child of @-'s parent (@--)
jj new @--

# Restore files from @ (bring changes down)
jj restore --from @

# Describe this commit
jj describe -m "changes that should be here"

# Abandon the old @
jj abandon @
```

**If changes should be in a different commit:**

```bash
# Find the commit they should be in
jj log

# Create new commit as child of target
jj new <target-commit>

# Restore changes from wrong commit
jj restore --from <wrong-commit>

# Describe
jj describe -m "moved changes"

# Clean up wrong commit if now empty
jj abandon <wrong-commit>
```

### Solution 2: Move specific files

```bash
# Move specific files from @ to parent

# Edit parent
jj edit @-

# Restore specific files from child (@-)
jj restore --from @- path/to/file.rs

# Return to child
jj edit @

# Remove the file from @ (restore from parent)
jj restore --from @- path/to/file.rs
```

### Solution 3: Using evolog to find state

**If you're not sure what happened:**

```bash
# View evolution with patches
jj evolog --patch

# Find snapshot before wrong changes
jj evolog | grep -B 5 "before the mistake"

# Restore from that snapshot
jj restore --from <commit-id>
```

**Complete recovery example:**

```bash
# 1. Check evolution to find good state
jj evolog --patch | less
# Find commit ID where things were good: abc123

# 2. Create new commit from good parent
jj new <good-parent>

# 3. Restore content from good snapshot
jj restore --from abc123

# 4. Describe appropriately
jj describe -m "recovered correct changes"

# 5. Move bookmarks if needed
jj bookmark move main --to @

# 6. Abandon bad commit
jj abandon <bad-commit>
```

## Q: How do I resume working on an existing change?

**Answer:** Use `jj new <rev>` then `jj squash` (recommended), or `jj edit` for direct amendment.

### Method 1: `jj new` + `jj squash` (recommended)

**Why recommended:**
- Preserves history in evolog
- Can review before squashing
- Safer (can undo)

```bash
# Create child of commit you want to continue
jj new <change-id>

# Make your additional changes
# ...

# When ready, squash into parent
jj squash

# The changes are now incorporated
```

**Example:**
```bash
# Find change to continue
jj log -r 'description("auth")'
# Change ID: abc123

# Create child
jj new abc123

# Continue work
echo "more auth code" >> auth.rs

# Review
jj diff

# Squash into parent
jj squash -m "enhance authentication with 2FA"
```

### Method 2: `jj edit` (direct amendment)

**When to use:**
- Quick fixes
- Correcting typos
- When you're sure about changes

```bash
# Edit commit directly
jj edit <change-id>

# Make changes in working directory
# Changes go directly into the commit

# Return to previous position
jj new @  # Or jj edit @ if that was your previous location
```

**Example:**
```bash
# Edit commit directly
jj edit abc123

# Fix typo
echo "corrected" >> file.rs

# Commit is automatically amended
# Return to latest work
jj edit <original-position>
```

### Comparison

| Method | Pros | Cons |
|--------|------|------|
| `new` + `squash` | Safe, reviewable, preserves history | Extra step |
| `edit` | Direct, quick | Changes immediate, harder to review |

**Best practice:** Default to `new` + `squash`, use `edit` for trivial fixes.

## Advanced Patterns

### Viewing specific file's evolution

```bash
# See how file changed through snapshots
jj evolog --patch -- path/to/file.rs

# Or use operation log
jj op log | head -20  # Find relevant operations
jj --at-op=<op-id> diff -- path/to/file.rs
```

### Recovering deleted files

```bash
# File was deleted, recover from evolog
jj evolog --patch | grep -B 10 "deleted_file.rs"

# Find snapshot with file
jj evolog | less
# Find commit ID: xyz789

# Restore file
jj restore --from xyz789 deleted_file.rs
```

### Comparing working copy snapshots

```bash
# Compare current @ with earlier snapshot
jj evolog --limit 5  # Find snapshot ID

# Show diff between snapshots
jj diff --from <old-snapshot> --to @
```

## Reference: Working Copy Commands

```bash
# Status and inspection
jj status                     # Working copy changes
jj log -r @                   # Current commit
jj diff -r @                  # Working copy diff
jj diff                       # Same as above

# Evolution history
jj evolog                     # Evolution of @
jj evolog -r <change-id>      # Specific change
jj evolog --patch             # With diffs
jj evolog --limit 10          # Last 10 snapshots
jj obslog                     # Alias for evolog

# File tracking
jj file track <path>          # Track file
jj file untrack <path>        # Untrack file
jj file list                  # List tracked files

# Restoration
jj restore --from <commit>    # Restore all files
jj restore --from <commit> <path>  # Restore specific files
jj restore --to <commit>      # Restore to destination

# Splitting
jj split -i                   # Interactive split
jj split <paths>              # Split by paths
jj commit -i                  # Alias for split -i

# Working with commits
jj new <rev>                  # Create child (resume pattern)
jj edit <rev>                 # Edit directly
jj squash                     # Squash @ into parent
```
