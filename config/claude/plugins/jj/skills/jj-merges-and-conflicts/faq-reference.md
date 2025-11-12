# Merges and Conflicts - Detailed FAQ

## Q: Why are most merge commits marked as "(empty)"?

**Answer:** Jujutsu is snapshot-based. Merge changes are calculated relative to auto-merged parents. Clean merges with no conflict resolution appear empty.

### Understanding the Model

**Git's diff-based model:**
```
Merge commit = Combination of parent1 + parent2 changes
Merge diff = Shows all changes from parent2
```

**Jujutsu's snapshot-based model:**
```
Merge commit = Snapshot of merged state
Merge changes = merge_snapshot - auto_merge(parent1, parent2)
```

### Why This Matters

**Example scenario:**

```
    B (add feature.rs)
   /
  A
   \
    C (add docs.md)
```

**Creating merge:**
```bash
jj new B C  # Creates merge commit M
```

**Merge commit M contains:**
- `feature.rs` (from B)
- `docs.md` (from C)
- Any conflict resolutions
- Any additional manual changes

**Merge changes (what jj shows):**
```
M - auto_merge(B, C) = ∅
```

Auto-merge already combined both files cleanly, so M has no additional changes.

**Result:**
```
jj log
◆  (empty) Merge B and C
├─╮
│ ◆ C add docs
◆ │ B add feature
```

The merge is "(empty)" because you didn't add anything beyond the automatic merge.

### When Merges Have Content

**Scenario 1: Conflict resolution**

```bash
# B and C both modify same file
jj new B C
# Conflicts:
# <<<<<<< Conflict markers
# ...
# >>>>>>>

# Resolve conflicts manually
# Edit files to resolve

# Now merge commit has changes:
# merge_changes = resolved_state - conflicted_state
```

The merge commit contains your conflict resolution decisions.

**Scenario 2: Manual changes during merge**

```bash
# Clean merge but you make additional changes
jj new B C  # Auto-merges cleanly

# Add extra changes
echo "merged" >> status.txt

# Merge commit now has content:
# merge_changes = auto_merge + status.txt change
```

**Scenario 3: Semantic merge**

```bash
# Both sides added features that need integration
jj new B C

# Even if no conflicts, you add integration code
echo "integrate features" >> main.rs

# Merge contains semantic integration
```

### Viewing Merge Content

```bash
# Show what merge commit added
jj show <merge-commit>

# If empty: clean auto-merge
# If has content: view conflict resolutions or manual changes

# Compare merge to each parent
jj diff --from <merge>^1 --to <merge>  # vs first parent
jj diff --from <merge>^2 --to <merge>  # vs second parent
```

### Git Comparison

**Git behavior:**
```bash
git show <merge-commit>
# Shows combined diff of both parents (confusing)
# Or full diff from one parent
```

**Jj behavior:**
```bash
jj show <merge-commit>
# Shows only what YOU added during merge
# Empty = you added nothing (clean auto-merge)
```

**Why jj's approach is clearer:**
- Separates automatic merge from manual changes
- Shows YOUR contribution to merge
- Empty merge = no manual intervention needed

## Q: How do I revert a merge commit?

**Answer:** Create a new commit with `jj new <merge>`, then `jj restore --from <first-parent>`. This undoes the second parent's changes.

### Understanding Merge Revert

**Scenario:**
```
@  : current work
│
◆  M : merge commit (merge of B and C)
├─╮
│ ◆ C : second parent (feature branch)
◆ │ B : first parent (main)
```

**Goal:** Undo changes from C, keep B.

### Step-by-Step Revert

```bash
# 1. Create new commit on merge
jj new M

# 2. Restore to first parent state
jj restore --from M^1

# Alternative syntax
jj restore --from 'M-'  # First parent
```

**Result:**
```
@  : revert commit (state = B)
│
◆  M : merge commit (state = B + C)
├─╮
│ ◆ C : second parent
◆ │ B : first parent
```

### Reverting Specific Files

```bash
# Revert only certain files from merge
jj new M
jj restore --from M^1 path/to/file.rs path/to/other.rs
```

### Alternative: Revert to Second Parent

```bash
# Keep second parent, undo first
jj new M
jj restore --from M^2  # or 'M+'
```

### Understanding Parent References

```
M^1 or M-  : First parent
M^2 or M+  : Second parent
M^  or M-  : First parent (default)
```

### After Reverting

```bash
# Describe the revert
jj describe -m "Revert merge of feature X"

# Continue working
jj new  # Create new commit
```

### Complex Revert Scenarios

**Revert part of merge:**
```bash
# Keep some changes from second parent
jj new M
jj restore --from M^1  # Revert everything

# Selectively re-apply some changes from M
jj restore --from M path/to/keep.rs
```

**Revert with conflicts:**
```bash
# If revert creates conflicts
jj new M
jj restore --from M^1
# Resolve any conflicts
jj describe -m "Revert with conflict resolution"
```

## Q: How do I handle divergent changes?

**Answer:** Divergent changes occur when the same change ID points to multiple commits. Use `jj log -r 'divergent()'` to find them, then resolve by choosing one commit or merging them.

**Note:** The FAQ mentions this but refers to the Guides section for details. Here's the comprehensive guide:

### What Causes Divergence?

**Scenario 1: Concurrent operations**

```bash
# Terminal 1
jj edit abc123
echo "change A" >> file.rs

# Terminal 2 (same repo, different workspace)
jj edit abc123
echo "change B" >> file.rs

# Both modified the same change -> divergent
```

**Scenario 2: Concurrent fetch/rebase**

```bash
# Local work on feature branch
# Remote also updated same branch
jj git fetch
# Now local and remote versions diverge
```

**Scenario 3: Manual divergence**

```bash
# Creating commits with same change ID manually
# (Advanced operations, usually unintentional)
```

### Detecting Divergence

```bash
# Find all divergent changes
jj log -r 'divergent()'

# Check specific change
jj log -r <change-id>
# Shows multiple commits if divergent

# Detailed view
jj log -r 'divergent()' --template '
  change_id.short() ++ " " ++
  commit_id.short() ++ " " ++
  description.first_line() ++ "\n"
'
```

### Resolution Strategy 1: Choose One

**When:** One version is clearly correct.

```bash
# Find divergent commits
jj log -r <change-id>

# Example output:
# ◆  abc xyz123 Version A
# ◆  abc xyz456 Version B

# Choose Version A
jj abandon xyz456

# Or choose Version B
jj abandon xyz123
```

After abandoning, only one version remains, resolving divergence.

### Resolution Strategy 2: Merge Them

**When:** Both versions have valuable changes.

```bash
# Find divergent commits
jj log -r <change-id>
# abc xyz123 (Version A)
# abc xyz456 (Version B)

# Create merge
jj new xyz123 xyz456

# Resolve any conflicts
# Describe the merge
jj describe -m "Merge divergent versions of <change>"

# Abandon old versions
jj abandon xyz123 xyz456

# Or keep them as history
```

### Resolution Strategy 3: Rebase One

**When:** One version should be based on the other.

```bash
# Rebase Version B onto Version A
jj rebase -s xyz456 -d xyz123

# Now xyz456 is child of xyz123
# No longer divergent (different change IDs now)
```

### Prevention

**Avoid divergence:**

1. **Don't concurrently edit same change** in multiple workspaces
2. **Use separate change IDs** for parallel work
3. **Coordinate with team** on shared branches
4. **Use bookmarks** to mark important states

**Working in multiple locations:**
```bash
# Instead of editing same change:
# Workspace 1
jj new abc123 -m "experiment A"

# Workspace 2
jj new abc123 -m "experiment B"

# Different change IDs, no divergence
```

### Automation

**Check for divergence before operations:**
```bash
#!/bin/bash
if jj log -r 'divergent()' --no-graph -T 'commit_id' | grep -q .; then
  echo "Warning: Divergent changes exist"
  jj log -r 'divergent()'
  exit 1
fi
```

## Q: How do I resolve conflicted bookmarks?

**Answer:** Use `jj bookmark move <name> --to <commit-id>`. Check `jj bookmark list` if commits aren't visible.

### Understanding Bookmark Conflicts

**What causes them:**

```bash
# Local state
main -> commit A

# Remote state (after others pushed)
main@origin -> commit B

# After fetch
jj git fetch
# Now main has two versions (conflicted)
```

**Detection:**
```bash
jj bookmark list

# Output might show:
# main: conflict
#   + abc123 (local)
#   + def456 (remote)
```

### Resolution Methods

### Method 1: Choose Local

```bash
# Keep local version
jj bookmark move main --to abc123

# Or using bookmark reference
jj bookmark move main --to main
```

### Method 2: Choose Remote

```bash
# Keep remote version
jj bookmark move main --to def456

# Or using bookmark reference
jj bookmark move main --to main@origin
```

### Method 3: Merge Both

```bash
# Create merge of both versions
jj new abc123 def456

# Describe merge
jj describe -m "Merge local and remote main"

# Move bookmark to merge
jj bookmark move main
```

### Method 4: Rebase Local

```bash
# Rebase local work onto remote
jj rebase -s abc123 -d def456

# Move bookmark to rebased commit
jj bookmark move main
```

### Handling Invisible Commits

**Problem:** Commits referenced in bookmark conflict aren't in `jj log`.

**Solution:**

```bash
# See all commits including hidden
jj log -r 'all()'

# Find the conflict commits
jj bookmark list  # Shows commit IDs

# Make commits visible
jj new abc123  # Creates child, makes visible
jj new def456  # Creates child, makes visible

# Now decide which to keep
jj bookmark move main --to <chosen-commit>
```

### Complex Bookmark Conflicts

**Multiple conflicted bookmarks:**
```bash
# List all
jj bookmark list

# Resolve each
jj bookmark move feature-1 --to <commit-id>
jj bookmark move feature-2 --to <commit-id>
jj bookmark move main --to <commit-id>
```

**Conflicted after complex history:**
```bash
# View full graph
jj log -r 'all()' --limit 50

# Understand the conflict
jj log -r 'bookmark(main) | bookmark(main@origin)'

# Make informed decision
jj bookmark move main --to <best-commit>
```

### Prevention

**Avoid bookmark conflicts:**

1. **Pull before push:**
   ```bash
   jj git fetch
   jj bookmark move main --to main@origin
   jj rebase -s <your-work> -d main
   jj git push
   ```

2. **Use separate bookmarks for features:**
   ```bash
   # Don't work directly on main
   jj bookmark set my-feature
   jj git push --bookmark my-feature
   ```

3. **Communicate with team:**
   - Coordinate who updates shared branches
   - Use pull requests instead of direct pushes

### Automation

**Auto-resolve to remote:**
```bash
# Script to always take remote version
for bookmark in $(jj bookmark list | grep conflict | awk '{print $1}'); do
  remote_commit=$(jj bookmark list | grep "$bookmark@origin" | awk '{print $2}')
  jj bookmark move $bookmark --to $remote_commit
done
```

## Advanced Topics

### Octopus Merges

**Create merge with 3+ parents:**
```bash
jj new A B C D
# Creates merge with 4 parents
```

**Use cases:**
- Merging multiple feature branches
- Synchronization points
- (Rare in practice)

### Criss-Cross Merges

**Scenario:**
```
  C --- D
 / \   / \
A   \ /   F
 \   X   /
  \ / \ /
   B   E
```

**Handling:**
Jj handles criss-cross merges automatically using recursive merge algorithm.

```bash
# Just create merge normally
jj new D E

# Jj finds appropriate merge bases
# Resolves conflicts if any
```

### Conflict Markers in Commits

**Jj stores conflicts in commits:**
```bash
# Create merge with conflicts
jj new A B
# Files have conflict markers

# Commit anyway
jj describe -m "Merge with conflicts"
jj new  # Conflicts propagate to child

# Resolve later
jj edit <commit-with-conflicts>
# Resolve conflicts
# Commit is automatically updated
```

**Viewing conflicts:**
```bash
# Find commits with conflicts
jj log -r 'conflict()'

# See conflict details
jj show <commit-with-conflict>
```

## Reference Commands

```bash
# Merges
jj new <parent1> <parent2>         # Create merge
jj merge <parent1> <parent2>       # Alias for new
jj log -r 'merges()'              # List merge commits
jj show <merge>                    # Show merge changes

# Parents
jj log -r '<commit>-'             # First parent
jj log -r '<commit>+'             # Second parent
jj log -r 'parents(<commit>)'     # All parents

# Reverting merges
jj new <merge>
jj restore --from '<merge>-'      # Revert to first parent

# Divergence
jj log -r 'divergent()'           # Find divergent changes
jj abandon <commit>                # Remove divergent version
jj new <commit1> <commit2>        # Merge divergent versions

# Bookmark conflicts
jj bookmark list                   # Show conflicts
jj bookmark move <name> --to <id> # Resolve conflict
jj log -r 'all()'                 # See hidden commits

# Conflicts
jj log -r 'conflict()'            # Find conflicted commits
jj edit <commit>                   # Resolve conflicts in commit
```
