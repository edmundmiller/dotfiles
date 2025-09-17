---
allowed-tools: Bash(jj next:*), Bash(jj prev:*), Bash(jj edit:*), Bash(jj log:*), Bash(jj status:*), Bash(jj diff:*)
argument-hint: [direction|change-id]
description: Navigate and edit changes in your history
model: claude-sonnet-4-20250514
---

## Navigate Between Changes

Move through your change history and edit any commit directly.

## Current Position
!`jj log -r ::@ --limit 7 --no-graph`

## Smart Navigation

!if [ "$ARGUMENTS" = "next" ]; then
  echo "### Moving Forward"
  echo ""
  echo "Move to the next change and start editing:"
  echo "\`\`\`bash"
  echo "jj next --edit"
  echo "\`\`\`"
  echo ""
  echo "This moves your working copy to the next change in the sequence."
elif [ "$ARGUMENTS" = "prev" ] || [ "$ARGUMENTS" = "previous" ]; then
  echo "### Moving Back"
  echo ""
  echo "Move to the previous change and start editing:"
  echo "\`\`\`bash"
  echo "jj prev --edit"
  echo "\`\`\`"
  echo ""
  echo "This moves your working copy to the previous change in the sequence."
elif [ "$ARGUMENTS" = "latest" ] || [ "$ARGUMENTS" = "tip" ]; then
  echo "### Return to Latest"
  echo ""
  echo "Return to the latest change:"
  echo "\`\`\`bash"
  echo "jj edit @"
  echo "\`\`\`"
  echo ""
  echo "The @ symbol always refers to your current/latest change."
elif [ "$ARGUMENTS" = "parent" ]; then
  echo "### Edit Parent Change"
  echo ""
  echo "Edit the parent of your current change:"
  echo "\`\`\`bash"
  echo "jj edit @-"
  echo "\`\`\`"
  echo ""
  echo "The @- symbol refers to the parent of current change."
elif [ -n "$ARGUMENTS" ]; then
  # Assume it's a change ID
  echo "### Jump to Specific Change"
  echo ""
  echo "Editing change: $ARGUMENTS"
  echo "\`\`\`bash"
  echo "jj edit $ARGUMENTS"
  echo "\`\`\`"
  echo ""
  echo "You can now modify this change. Use navigation commands to move around."
else
  echo "## Navigation Options"
  echo ""
  echo "### Quick Navigation:"
  echo ""
  echo "1. **Move forward**"
  echo "   \`\`\`bash"
  echo "   jj next --edit     # Move to next change"
  echo "   \`\`\`"
  echo ""
  echo "2. **Move backward**"
  echo "   \`\`\`bash"
  echo "   jj prev --edit     # Move to previous change"
  echo "   \`\`\`"
  echo ""
  echo "3. **Jump to specific change**"
  echo "   \`\`\`bash"
  echo "   jj edit <change-id>  # Edit any change by ID"
  echo "   \`\`\`"
  echo ""
  echo "4. **Return to latest**"
  echo "   \`\`\`bash"
  echo "   jj edit @          # Back to tip"
  echo "   \`\`\`"
  echo ""
  echo "### Shortcuts:"
  echo "- \`@navigate next\` - Move forward"
  echo "- \`@navigate prev\` - Move backward"
  echo "- \`@navigate latest\` - Return to tip"
  echo "- \`@navigate parent\` - Edit parent change"
  echo "- \`@navigate <id>\` - Edit specific change"
fi

### Understanding Change References:

- **@** - Current change (tip of your branch)
- **@-** - Parent of current change
- **@--** - Grandparent of current change
- **<change-id>** - Specific change by its unique ID

### Key Benefits:

- **No checkout dance**: Just edit any change directly
- **Automatic rebasing**: Children follow when you edit parents
- **Safe navigation**: Always undoable with `@undo`
- **Working copy clarity**: Always know which change you're editing

**Pro tip**: Use `jj log` frequently to see your position in the change graph.