---
allowed-tools: Bash(jj describe:*), Bash(jj log:*), Bash(jj status:*), Bash(jj show:*), Bash(jj diff:*)
argument-hint: [commit-message]
description: Write clear commit messages - describe intent first!
model: claude-sonnet-4-20250514
---

## Current Commit
!`jj log -r @ --no-graph`

## Describe Your Changes

!# Check if this is intent (no changes) vs completion (has changes)
has_changes=$(jj status --no-pager 2>/dev/null | grep -E "^[AM]" || echo "")

if [ -n "$ARGUMENTS" ]; then
  echo "Setting description: $ARGUMENTS"
  jj describe -m "$ARGUMENTS"
  echo ""
  if [ -z "$has_changes" ]; then
    echo "✅ **Intent described!** Next steps:"
    echo "1. \`jj new\` - Create workspace for implementation"
    echo "2. Implement your described changes"
    echo "3. \`jj squash\` - Complete the work"
    echo ""
    echo "Or use: \`@squash-workflow step2\` for guided workflow"
  else
    echo "✅ **Description updated for implemented changes**"
  fi
else
  if [ -z "$has_changes" ]; then
    echo "💡 **Describe your INTENT** (squash workflow step 1)"
    echo ""
    echo "The jj way: **Describe what you plan to build BEFORE implementing**"
    echo ""
    echo "### Intent-based examples:"
    echo "- \`@describe \"feat: implement user authentication\"\`"
    echo "- \`@describe \"fix: resolve login timeout issue\"\`"
    echo "- \`@describe \"refactor: extract payment service\"\`"
    echo ""
    echo "**After describing intent:**"
    echo "1. \`jj new\` - Create implementation workspace"
    echo "2. Build what you described"
    echo "3. \`jj squash\` - Complete focused commit"
  else
    echo "📝 **Describe your COMPLETED work**"
    echo ""
    echo "You have implemented changes. Describe what you built:"
  fi
  echo ""
  echo "### Conventional Commit Format:"
  echo "- \`feat:\` - New features"
  echo "- \`fix:\` - Bug fixes"
  echo "- \`docs:\` - Documentation changes"
  echo "- \`refactor:\` - Code restructuring"
  echo "- \`test:\` - Testing improvements"
  echo "- \`chore:\` - Maintenance tasks"
  echo ""
  echo "### Advanced options:"
  echo "\`\`\`bash"
  echo "jj describe  # Opens editor for multi-line messages"
  echo "\`\`\`"
fi

### Current changes:
!`jj diff --summary`

**Philosophy**: In jj, describe your intent first, then implement. This creates focused commits that tell a clear story.