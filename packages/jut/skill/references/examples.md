# jut Workflow Examples

Real-world examples of common workflows.

**Note on IDs:** Examples use illustrative IDs like `abc`, `def`. In practice, always read actual IDs from `jut status --json` output (`short_id` field).

## Example 1: Start a New Feature

```bash
# 1. Update to latest
jut pull --clean --json --status-after

# 2. Create branch from trunk
jut branch my-feature --json --status-after

# 3. Make changes, then commit
# (edit src/feature.rs)
jut commit -m "implement feature" --json --status-after

# 4. Push and create PR
jut push --json --status-after
jut pr --json
```

## Example 2: Stacked Features (Dependent Work)

```bash
# 1. Create base feature
jut branch auth --json --status-after
# (implement auth)
jut commit -m "add authentication" --json --status-after

# 2. Stack dependent work on top
jut branch profile --stack --json --status-after
# (implement profile, which needs auth)
jut commit -m "add user profile" --json --status-after

# 3. Push both
jut push auth --json --status-after
jut push profile --json --status-after

# 4. Create PRs (profile PR depends on auth PR)
jut pr auth --json
jut pr profile --json
```

## Example 3: Amend a File into an Older Commit

```bash
# 1. See workspace state
jut status --json

# Output shows revision abc has "add validation"
# Working copy has changes to src/validate.rs

# 2. Amend the file into that commit
jut rub src/validate.rs abc --json --status-after

# Alternative: use implicit rub
jut src/validate.rs abc --json --status-after
```

## Example 4: Discard Changes

### Discard a file

```bash
# Option A: rub to discard target
jut rub src/experiment.rs zz --json --status-after

# Option B: discard command
jut discard src/experiment.rs --json --status-after
```

### Abandon a revision

```bash
# Option A: rub to discard target
jut rub abc zz --json --status-after

# Option B: discard command
jut discard abc --json --status-after
```

## Example 5: Squash Commits

### Squash working copy into parent

```bash
jut squash --json --status-after
```

### Squash a specific revision into another

```bash
# Squash revision abc into def
jut squash abc def --json --status-after

# With a new message
jut squash abc def -m "combined feature" --json --status-after
```

## Example 6: Absorb Changes into the Right Commits

```bash
# 1. Preview what would happen
jut absorb --dry-run --json

# 2. If plan looks good, apply
jut absorb --json --status-after
```

Absorb analyzes your working copy changes and amends each hunk into the commit where it belongs, based on which commit last touched those lines.

## Example 7: Clean Up After Pull

```bash
# Fetch + rebase + auto-delete merged bookmarks
jut pull --clean --json --status-after

# Output:
# {
#   "fetched": true,
#   "rebased": true,
#   "merged_bookmarks": ["old-feature", "shipped-fix"],
#   "cleaned_bookmarks": ["old-feature", "shipped-fix"],
#   "conflicts": []
# }
```

## Example 8: Undo a Mistake

### Simple undo (last operation)

```bash
jut undo --json --status-after
```

### Go further back via oplog

```bash
# 1. View operation history
jut oplog --json

# 2. Find the operation you want to restore to
# 3. Restore to that point
jut oplog restore <op-id> --json --status-after
```

## Example 9: Split a Commit (Drop to jj)

```bash
# 1. Find the revision to split
jut status --json

# 2. Interactive split in jj
jj split -r abc

# 3. Refresh state
jut status --json
```

jut doesn't wrap `jj split` because it's interactive — jj's native TUI is the best experience.

## Example 10: Rebase Work (Drop to jj)

```bash
# Move revision abc onto def
jj rebase -r abc -d def

# Refresh state
jut status --json
```

Complex rebasing with revsets is better expressed in raw jj.

## Example 11: Resolve Conflicts (Drop to jj)

```bash
# 1. Check for conflicts after pull
jut status --json
# Look for "is_conflicted": true in revisions

# 2. Resolve with jj's merge tool
jj resolve -r abc

# 3. Verify resolution
jut status --json
```

## Example 12: Daily Development Workflow

```bash
# Morning: sync with upstream
jut pull --clean --json --status-after

# Start work
jut branch fix-auth-bug --json --status-after

# Iterate
# (make changes)
jut commit -m "identify auth bug source" --json --status-after
# (make more changes)
jut commit -m "fix token expiration" --json --status-after

# Small fix that belongs in the first commit
# (edit the file)
jut absorb --json --status-after

# Switch to urgent fix (drop to jj for navigation)
jj new -r trunk()
jut branch hotfix-login --json --status-after
# (make fix)
jut commit -m "fix login redirect loop" --json --status-after
jut push --json --status-after
jut pr --json

# Back to original work (drop to jj)
jj edit <fix-auth-bug-revision>
# (continue working)
jut commit -m "add tests for token handling" --json --status-after

# End of day: ship it
jut push --json --status-after
jut pr --json
```

## Example 13: Rename and Reorganize Branches

```bash
# Rename a branch
jut branch --rename old-name new-name --json --status-after

# Delete a merged branch
jut branch -d shipped-feature --json --status-after

# List all branches with stack relationships
jut branch -l --json
```

## Tips

### JSON for Scripting

```bash
jut status --json | jq '.stacks[].bookmarks'
jut log --json | jq '.revisions[] | select(.is_conflicted) | .short_id'
```

### Environment Variable for Default JSON

```bash
export JUT_OUTPUT_FORMAT=json
jut status  # now outputs JSON by default
```

### Combine with `--status-after`

After any mutation, `--status-after` appends the full workspace state. This eliminates a round-trip for agents:

```bash
jut commit -m "fix" --json --status-after
# Returns commit result + full workspace state in one response
```
