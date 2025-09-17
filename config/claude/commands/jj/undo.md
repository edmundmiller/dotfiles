---
allowed-tools: Bash(jj op log:*), Bash(jj op restore:*), Bash(jj undo:*), Bash(jj status:*), Bash(jj log:*)
argument-hint: [operation-id]
description: Safety net - undo any operation (everything is undoable!)
model: claude-sonnet-4-20250514
---

## Recent Operations
!`jj op log --limit 8`

## Safety Net 🛡️

**Everything in jj is undoable!** No operation is ever truly destructive.

!if [ -n "$ARGUMENTS" ]; then
  echo "### Restoring to specific operation: $ARGUMENTS"
  echo ""
  echo "Time-traveling to operation $ARGUMENTS:"
  echo "\`\`\`bash"
  echo "jj op restore $ARGUMENTS"
  echo "\`\`\`"
  echo ""
  echo "This will restore your repository to exactly how it was at that point."
else
  echo "### Recovery Options"
  echo ""
  echo "**1. Undo last operation** (Most common)"
  echo "   \`\`\`bash"
  echo "   jj undo"
  echo "   \`\`\`"
  echo "   Reverses the most recent operation"
  echo ""
  echo "**2. Time-travel to specific point**"
  echo "   \`\`\`bash"
  echo "   jj op restore <operation-id>  # Use ID from op log above"
  echo "   \`\`\`"
  echo ""
  echo "**3. View more operation history**"
  echo "   \`\`\`bash"
  echo "   jj op log --limit 20  # See more operations"
  echo "   \`\`\`"
fi

### Common Recovery Scenarios:

❌ **Accidental squash**: `jj undo`
❌ **Wrong split**: `jj undo`
❌ **Bad rebase**: `jj undo`
❌ **Mistaken abandon**: `jj undo`
❌ **Wrong edit**: `jj undo`
❌ **Any mistake**: `jj undo` or `jj op restore <id>`

### Understanding Operations:

Every action creates an operation:
- `describe` - Sets commit messages
- `new` - Creates changes
- `squash` - Moves changes between commits
- `split` - Divides commits
- `rebase` - Reorganizes history
- `abandon` - Removes commits

### Safety Philosophy:

🔄 **You can undo an undo**: If `jj undo` goes too far, just `jj undo` again
⏰ **Time travel**: Jump to any point with `jj op restore`
📚 **Complete history**: `jj op log` shows everything you've ever done
🛡️ **No data loss**: Even "destructive" operations are preserved

### Current state:
!`jj status`

**Remember**: In jj, "oops" is never permanent. When in doubt, just undo!