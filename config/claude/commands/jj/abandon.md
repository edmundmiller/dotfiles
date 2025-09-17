---
allowed-tools: Bash(jj abandon:*), Bash(jj log:*), Bash(jj status:*), Bash(jj diff:*), Bash(jj op log:*)
argument-hint: [change-id]
description: Safely discard unwanted changes
model: claude-sonnet-4-20250514
---

## Abandon Unwanted Changes

Safely remove changes you no longer need. Unlike Git, abandoning is always safe and undoable.

## Current Status
!`jj status`
!`jj log -r ::@ --limit 5 --no-graph`

## Safe Abandonment

!if [ -n "$ARGUMENTS" ]; then
  echo "### Abandoning Change: $ARGUMENTS"
  echo ""
  echo "This will safely remove the specified change:"
  echo "\`\`\`bash"
  echo "jj abandon $ARGUMENTS"
  echo "\`\`\`"
  echo ""
  echo "**What happens:**"
  echo "- Change is removed from history"
  echo "- Descendants automatically rebase"
  echo "- Operation is fully undoable"
  echo ""
  echo "**Safety check:** Review the change first:"
  echo "\`\`\`bash"
  echo "jj show $ARGUMENTS"
  echo "\`\`\`"
else
  echo "## When to Abandon Changes"
  echo ""
  echo "✅ **Common scenarios:**"
  echo "- Empty commits that served as placeholders"
  echo "- Experimental work that didn't pan out"
  echo "- Duplicate commits or wrong implementations"
  echo "- Changes that are no longer needed"
  echo ""
  echo "### Abandon Current Change"
  echo ""
  echo "Remove the change you're currently on:"
  echo "\`\`\`bash"
  echo "jj abandon @"
  echo "\`\`\`"
  echo ""
  echo "### Abandon Specific Change"
  echo ""
  echo "Remove any change by its ID:"
  echo "\`\`\`bash"
  echo "jj abandon <change-id>"
  echo "\`\`\`"
  echo ""
  echo "### Abandon Empty Changes"
  echo ""
  echo "Remove all empty changes in your history:"
  echo "\`\`\`bash"
  echo "jj abandon 'empty()'"
  echo "\`\`\`"
fi

### What Happens During Abandon:

1. **Change removal**: The specified change disappears from history
2. **Automatic rebasing**: Any descendants are rebased onto the abandoned change's parent
3. **Working copy update**: If you abandoned the current change, working copy moves to the parent
4. **Preservation**: The operation is recorded and can be undone

### Safety Features:

- **Always undoable**: Use `@undo` or `jj op restore` to recover
- **No data loss**: Changes are preserved in operation log
- **Automatic rebasing**: Descendants are automatically preserved
- **Conflict handling**: If rebasing creates conflicts, they're stored safely

### Recovery Options:

If you abandon something by mistake:

```bash
jj undo                    # Undo the abandon operation
jj op log                  # See operation history
jj op restore <op-id>      # Restore to specific point
```

### Current changes preview:
!`jj diff --summary`

**Remember**: Abandoning is the safe way to remove unwanted changes in jj. Everything is always recoverable!