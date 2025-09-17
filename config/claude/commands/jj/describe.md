---
allowed-tools: Bash(jj describe:*), Bash(jj log:*), Bash(jj status:*), Bash(jj show:*), Bash(jj diff:*)
argument-hint: [commit-message]
description: Write clear commit messages
model: claude-sonnet-4-20250514
---

## Current Commit
!`jj log -r @ --no-graph`

## Describe Your Changes

!if [ -n "$ARGUMENTS" ]; then
  echo "Setting commit message: $ARGUMENTS"
  jj describe -m "$ARGUMENTS"
else
  echo "I'll help you write a clear commit message."
  echo ""
  echo "### Quick Options:"
  echo ""
  echo "1. **Simple message**"
  echo "   \`\`\`bash"
  echo "   jj describe -m \"your message\""
  echo "   \`\`\`"
  echo ""
  echo "2. **Conventional commit**"
  echo "   \`\`\`bash"
  echo "   jj describe -m \"type: description\""
  echo "   \`\`\`"
  echo "   Types: \`feat\`, \`fix\`, \`docs\`, \`refactor\`, \`test\`, \`chore\`"
  echo ""
  echo "3. **Edit in editor**"
  echo "   \`\`\`bash"
  echo "   jj describe  # Opens your editor"
  echo "   \`\`\`"
fi

### Current changes:
!`jj diff --summary`

What type of change is this? I'll help you write an appropriate message.