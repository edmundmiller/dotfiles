# JJ + Beads Merge Conflicts

When resolving merge conflicts in `.beads/issues.jsonl` files, use the beads-merge tool:

```bash
jj resolve --tool=beads-merge
```

## Why beads-merge?

Beads stores issues as JSON objects in `.beads/issues.jsonl`. The `bd merge` tool performs **field-level 3-way merging** instead of line-based merging, which prevents false conflicts when two people edit different fields of the same issue.

**Example:**
- You change `status: "open"` → `"in_progress"`
- Coworker changes `priority: 2` → `3`
- Line-based merge: CONFLICT (same line changed)
- Field-based merge: SUCCESS (both changes preserved)

## When to use beads-merge

- Conflicts in `.beads/issues.jsonl`
- Any file in a `.beads/` directory

## When NOT to use beads-merge

For all other files, use the default merge tool:

```bash
jj resolve  # Uses diffconflicts (nvim)
```
