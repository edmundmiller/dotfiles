---
allowed-tools: Bash(jj new:*), Bash(jj status:*), Bash(jj log:*), Bash(jj describe:*)
argument-hint: [description]
description: Start new work - the essential first step
model: claude-sonnet-4-20250514
---

## Current Status
!`jj status`
!`jj log -r ::@ --limit 3 --no-graph`

## Start New Work

**Note**: In the squash workflow, you typically describe first, then create new work.
For the complete pattern, use `@squash-workflow` instead.

!if [ -n "$ARGUMENTS" ]; then
  echo "Creating new change: $ARGUMENTS"
  jj new -m "$ARGUMENTS"
else
  echo "### Current situation check..."
  echo ""
  current_desc=$(jj log -r @ -T description --no-graph 2>/dev/null || echo "")
  if [ "$current_desc" = "(no description set)" ] || [ -z "$current_desc" ]; then
    echo "💡 **Recommendation**: Describe your current work first:"
    echo "   \`@describe \"what you're building\"\`"
    echo "   Then use: \`@new\` (or \`@squash-workflow\` for full guidance)"
    echo ""
  fi
  echo "### Quick options:"
  echo ""
  echo "1. **Create empty change**"
  echo "   \`\`\`bash"
  echo "   jj new"
  echo "   \`\`\`"
  echo ""
  echo "2. **Create with description**"
  echo "   \`\`\`bash"
  echo "   jj new -m \"feat: implement user authentication\""
  echo "   \`\`\`"
  echo ""
  echo "3. **Insert before current** (advanced)"
  echo "   \`\`\`bash"
  echo "   jj new -B @ -m \"fix: urgent bugfix\""
  echo "   \`\`\`"
  echo ""
  echo "**Recommended**: Use \`@squash-workflow\` for guided workflow"
fi

### What `jj new` does:

- Creates a new empty change
- Moves working copy to the new change
- Preserves all previous work in parent commits
- Ready for implementation without affecting existing work

### Next steps:
- Implement your changes (edit files, run tests)
- Use `@squash` to complete the work
- Or `@squash-workflow` for full guidance