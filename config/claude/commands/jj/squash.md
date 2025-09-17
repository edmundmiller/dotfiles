---
allowed-tools: Bash(jj squash:*), Bash(jj status:*), Bash(jj log:*), Bash(jj diff:*), Bash(jj show:*)
argument-hint: [commit-message]
description: Complete work via squash workflow
model: claude-sonnet-4-20250514
---

## Current Status
!`jj status`
!`jj log -r ::@ --limit 3 --no-graph`

## Squash Workflow

The squash workflow in jj: **Describe → New → Implement → Squash**

I'll help you complete your current work by squashing changes into the parent commit.

!if [ -n "$ARGUMENTS" ]; then
  echo "Squashing with message: $ARGUMENTS"
  jj squash -m "$ARGUMENTS"
else
  echo "### What would you like to do?"
  echo ""
  echo "1. **Quick squash** - Move all current changes into parent"
  echo "   \`\`\`bash"
  echo "   jj squash"
  echo "   \`\`\`"
  echo ""
  echo "2. **Interactive squash** - Choose specific changes"
  echo "   \`\`\`bash"
  echo "   jj squash -i  # Opens editor to select hunks"
  echo "   \`\`\`"
  echo ""
  echo "3. **Squash with message** - Update commit message while squashing"
  echo "   \`\`\`bash"
  echo "   jj squash -m \"feat: completed feature\""
  echo "   \`\`\`"
fi

### Current changes to squash:
!`jj diff --summary`

Let me know if you want to:
- Squash everything into the parent commit
- Select specific changes interactively
- Update the commit message first