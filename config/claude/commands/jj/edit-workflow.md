---
allowed-tools: Bash(jj new:*), Bash(jj edit:*), Bash(jj next:*), Bash(jj prev:*), Bash(jj status:*), Bash(jj log:*), Bash(jj diff:*)
argument-hint: [change-id|operation]
description: Dynamic change manipulation - for complex multi-commit workflows
model: claude-sonnet-4-20250514
---

## The Edit Workflow 🔧 **ADVANCED**

**Pattern**: Dynamic navigation and insertion between changes

Best for complex features requiring multiple related commits or when you need to insert changes mid-history.

## Current Status
!`jj status`
!`jj log -r ::@ --limit 5 --no-graph`

## Intelligent Operations

!if [ "$ARGUMENTS" = "start" ]; then
  echo "### Starting Edit Workflow"
  echo ""
  echo "Create your first change for the feature:"
  echo "\`\`\`bash"
  echo "jj new -m \"feat: start complex feature\""
  echo "\`\`\`"
  echo ""
  echo "**Next steps:**"
  echo "- Implement initial version"
  echo "- Use \`@edit-workflow insert\` to add prerequisites"
  echo "- Use \`@edit-workflow navigate\` to move between changes"
elif [ "$ARGUMENTS" = "insert" ]; then
  echo "### Insert Change Before Current"
  echo ""
  echo "When you realize you need a prerequisite change:"
  echo "\`\`\`bash"
  echo "jj new -B @ -m \"feat: add prerequisite functionality\""
  echo "\`\`\`"
  echo ""
  echo "**What happens:**"
  echo "- New change inserted before current"
  echo "- Current change automatically rebases on top"
  echo "- Working copy moves to new change"
  echo "- No manual rebasing needed!"
  echo ""
  echo "Implement the prerequisite, then navigate with: \`@edit-workflow navigate\`"
elif [ "$ARGUMENTS" = "navigate" ]; then
  echo "### Navigate Between Changes"
  echo ""
  echo "Move through your change stack:"
  echo ""
  echo "**Forward navigation:**"
  echo "\`\`\`bash"
  echo "jj next --edit  # Move to next change and edit it"
  echo "\`\`\`"
  echo ""
  echo "**Backward navigation:**"
  echo "\`\`\`bash"
  echo "jj prev --edit  # Move to previous change and edit it"
  echo "\`\`\`"
  echo ""
  echo "**Jump to specific change:**"
  echo "\`\`\`bash"
  echo "jj edit <change-id>  # Edit any change by ID"
  echo "\`\`\`"
  echo ""
  echo "**Key insight:** Each change can be independently modified"
elif [ "$ARGUMENTS" = "example" ]; then
  echo "### Complete Edit Workflow Example"
  echo ""
  echo "\`\`\`bash"
  echo "# 1. Start feature"
  echo "jj new -m \"feat: user dashboard with analytics\""
  echo "# Implement basic dashboard..."
  echo ""
  echo "# 2. Realize you need authentication first"
  echo "jj new -B @ -m \"feat: add user authentication\""
  echo "# Implement auth system..."
  echo ""
  echo "# 3. Navigate back to dashboard work"
  echo "jj next --edit"
  echo "# Continue dashboard implementation..."
  echo ""
  echo "# 4. Add another prerequisite"
  echo "jj new -B @ -m \"feat: user data models\""
  echo "# Implement data models..."
  echo "\`\`\`"
  echo ""
  echo "**Result:** Clean sequence of logical commits"
elif [ -n "$ARGUMENTS" ]; then
  # Assume it's a change ID to edit
  echo "### Editing Specific Change"
  echo ""
  echo "Switching to change: $ARGUMENTS"
  echo "\`\`\`bash"
  echo "jj edit $ARGUMENTS"
  echo "\`\`\`"
  echo ""
  echo "You can now modify this change. When done:"
  echo "- \`jj next --edit\` - Move to next change"
  echo "- \`jj edit @\` - Return to latest change"
  echo "- \`@edit-workflow navigate\` - Navigation help"
else
  echo "## When to Use Edit Workflow"
  echo ""
  echo "✅ **Good for:**"
  echo "- Complex features needing multiple commits"
  echo "- When you discover prerequisites mid-development"
  echo "- Refactoring existing change sequences"
  echo "- Building layered functionality"
  echo ""
  echo "❌ **Avoid for:**"
  echo "- Simple, single-focused changes (use squash workflow)"
  echo "- Linear development without dependencies"
  echo "- When you're unsure of the final structure"
  echo ""
  echo "### Quick Operations:"
  echo "- \`@edit-workflow start\` - Begin complex feature"
  echo "- \`@edit-workflow insert\` - Add prerequisite change"
  echo "- \`@edit-workflow navigate\` - Move between changes"
  echo "- \`@edit-workflow example\` - See complete example"
  echo "- \`@edit-workflow <change-id>\` - Edit specific change"
fi

### Key Advantages:

- **Automatic rebasing**: Dependencies update automatically
- **Flexible insertion**: Add changes anywhere in history
- **Independent editing**: Modify any change without affecting others
- **Clear structure**: Each commit represents a logical unit

**Remember**: The edit workflow excels when you need fine-grained control over commit structure.