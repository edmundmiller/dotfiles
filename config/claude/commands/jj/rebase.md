---
allowed-tools: Bash(jj rebase:*), Bash(jj status:*), Bash(jj log:*), Bash(jj branch:*), Bash(jj op log:*)
argument-hint: [destination]
description: Reorganize commits with automatic rebasing (conflicts don't block!)
model: claude-sonnet-4-20250514
---

## Current Structure
!`jj log -r ::@ --limit 8`

## Rebase Operations 🔄

Reorganize your commit structure. Unlike Git, jj rebasing never fails or blocks.

!if [ -n "$ARGUMENTS" ]; then
  echo "### Rebasing onto: $ARGUMENTS"
  echo ""
  echo "Moving current commit to new base:"
  echo "\`\`\`bash"
  echo "jj rebase -d $ARGUMENTS"
  echo "\`\`\`"
  echo ""
  echo "**What happens:**"
  echo "- Current commit moves to new base"
  echo "- All descendants follow automatically"
  echo "- Conflicts are handled gracefully"
else
  echo "### Common Rebase Operations"
  echo ""
  echo "**1. Update with main branch**"
  echo "   \`\`\`bash"
  echo "   jj rebase -d main  # Move current commit onto main"
  echo "   \`\`\`"
  echo ""
  echo "**2. Rebase onto parent's parent**"
  echo "   \`\`\`bash"
  echo "   jj rebase -d @--  # Skip intermediate commit"
  echo "   \`\`\`"
  echo ""
  echo "**3. Move specific commit**"
  echo "   \`\`\`bash"
  echo "   jj rebase -r <commit-id> -d <new-parent>"
  echo "   \`\`\`"
  echo ""
  echo "**4. Rebase specific commit onto current**"
  echo "   \`\`\`bash"
  echo "   jj rebase -r <commit-id> -d @"
  echo "   \`\`\`"
fi

### Jujutsu's Rebase Superpowers:

🚀 **Always succeeds**: Conflicts never block rebasing
🔄 **Automatic descendants**: Children follow automatically
🛡️ **Conflict storage**: Conflicts stored in commits, not working directory
⚡ **No interactive mode**: No complex conflict resolution flow
🎯 **Precise control**: Rebase any commit to any destination

### Understanding Conflict Handling:

Unlike Git, jj handles conflicts elegantly:
- **Rebasing never fails**: Operation always completes
- **Conflicts in commits**: Stored as conflict markers in commit content
- **Working directory clean**: Conflicts don't pollute your workspace
- **Gradual resolution**: Resolve conflicts when you're ready

### Common Scenarios:

📈 **Update feature branch**:
```bash
jj rebase -d main  # Get latest main changes
```

🔧 **Reorganize commits**:
```bash
jj rebase -r <commit> -d <new-base>  # Move specific commit
```

🧹 **Clean up history**:
```bash
jj rebase -d @--  # Skip intermediate commit
```

### Available branches:
!`jj branch list`

### Safety reminder:
Everything is undoable with `@undo` or `jj op restore`!

**Philosophy**: In jj, rebasing is a safe, everyday operation for organizing your work.