---
allowed-tools: Bash(jj squash:*), Bash(jj status:*), Bash(jj log:*), Bash(jj diff:*), Bash(jj show:*)
argument-hint: [commit-message]
description: Complete work via squash workflow - the final step!
model: claude-sonnet-4-20250514
---

## Current Status
!`jj status`
!`jj log -r ::@ --limit 3 --no-graph`

## Complete Your Work 🎯

**Step 4 of squash workflow: Move implementation into described commit**

!# Intelligent squash guidance based on current state
has_changes=$(jj status --no-pager 2>/dev/null | grep -E "^[AM]" || echo "")
parent_desc=$(jj log -r @- -T description --no-graph 2>/dev/null || echo "")

if [ -z "$has_changes" ]; then
  echo "❌ **No changes to squash**"
  echo ""
  echo "You don't have any changes in your current commit."
  echo ""
  echo "**Possible next steps:**"
  echo "1. Implement changes first, then squash"
  echo "2. Start new work: \`@squash-workflow \"description\"\`"
  echo "3. Navigate to different change: \`@navigate\`"
elif [ "$parent_desc" = "(no description set)" ] || [ -z "$parent_desc" ]; then
  echo "⚠️  **Parent has no description**"
  echo ""
  echo "Consider describing the parent commit first:"
  echo "\`@navigate parent\` then \`@describe \"what this will be\"\`"
  echo ""
  echo "Or squash with a new message:"
  if [ -n "$ARGUMENTS" ]; then
    echo "Squashing with new message: $ARGUMENTS"
    jj squash -m "$ARGUMENTS"
  else
    echo "\`@squash \"feat: your description here\"\`"
  fi
else
  if [ -n "$ARGUMENTS" ]; then
    echo "🚀 **Squashing with updated message: $ARGUMENTS**"
    jj squash -m "$ARGUMENTS"
    echo ""
    echo "✅ **Workflow complete!** Changes moved into described commit."
  else
    echo "✅ **Ready to complete squash workflow**"
    echo ""
    echo "**Target commit:** \`$parent_desc\`"
    echo ""
    echo "### Squash options:"
    echo ""
    echo "1. **Complete the workflow** (Recommended)"
    echo "   \`\`\`bash"
    echo "   jj squash  # Move all changes to parent"
    echo "   \`\`\`"
    echo ""
    echo "2. **Interactive selection**"
    echo "   \`\`\`bash"
    echo "   jj squash -i  # Choose specific changes"
    echo "   \`\`\`"
    echo ""
    echo "3. **Update message while squashing**"
    echo "   \`\`\`bash"
    echo "   jj squash -m \"updated description\""
    echo "   \`\`\`"
    echo ""
    echo "4. **Partial squash by file**"
    echo "   \`\`\`bash"
    echo "   jj squash path/to/file.js  # Squash specific files"
    echo "   \`\`\`"
  fi
fi

### Changes ready to squash:
!`jj diff --summary`

### What squashing does:
- Moves your implementation from current commit → parent commit
- Creates clean, focused commit ready for review/push
- Completes the squash workflow cycle
- Working copy moves to the parent (now containing your work)

**Remember**: This is the final step that creates your polished commit!