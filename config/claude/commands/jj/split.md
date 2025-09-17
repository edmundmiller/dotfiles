---
allowed-tools: Bash(jj split:*), Bash(jj status:*), Bash(jj log:*), Bash(jj diff:*), Bash(jj describe:*)
argument-hint: [file-path]
description: Split mixed changes into focused commits
model: claude-sonnet-4-20250514
---

## Current Status
!`jj status`
!`jj diff --summary`

## Split Mixed Changes 🔀

Transform one commit with mixed concerns into multiple focused commits.

!# Check if there are changes to split
has_changes=$(jj status --no-pager 2>/dev/null | grep -E "^[AM]" || echo "")

if [ -z "$has_changes" ]; then
  echo "❌ **No changes to split**"
  echo ""
  echo "You need changes in your current commit to split them."
  echo ""
  echo "**Options:**"
  echo "1. Make some changes first"
  echo "2. Navigate to a commit with changes: \`@navigate\`"
  echo "3. Start new work: \`@squash-workflow\`"
elif [ -n "$ARGUMENTS" ]; then
  echo "### Splitting specific file: $ARGUMENTS"
  echo ""
  echo "Moving \`$ARGUMENTS\` to a new child commit:"
  echo "\`\`\`bash"
  echo "jj split $ARGUMENTS"
  echo "\`\`\`"
  echo ""
  echo "**After splitting:**"
  echo "- \`$ARGUMENTS\` moves to new child commit"
  echo "- Other changes remain in current commit"
  echo "- Describe each commit separately"
else
  echo "### Split Strategies"
  echo ""
  echo "**1. Interactive split** (Recommended)"
  echo "   ```bash"
  echo "   jj split  # Opens hunk selection interface"
  echo "   ```"
  echo "   Choose exactly which changes belong together"
  echo ""
  echo "**2. Split by files**"
  echo "   ```bash"
  echo "   jj split path/to/file.js  # Move specific files"
  echo "   jj split src/ tests/      # Move multiple paths"
  echo "   ```"
  echo ""
  echo "**3. Split by concern**"
  echo "   - Separate bug fixes from features"
  echo "   - Isolate refactoring from new functionality"
  echo "   - Split tests from implementation"
fi

### When to split:

✅ **Good candidates:**
- Bug fix + unrelated feature
- Implementation + tests
- Refactoring + new functionality
- Multiple independent changes

❌ **Don't split:**
- Tightly coupled changes
- Implementation and its required tests
- Changes that don't work independently

### How splitting works:

1. **Selection**: Choose which changes move to new commit
2. **New child created**: Selected changes → new child commit
3. **Remaining changes**: Stay in current commit
4. **Describe separately**: Each commit gets its own focused description

### After splitting:

```bash
jj describe -m "fix: bug description"     # Describe current commit
jj next --edit                           # Move to child commit
jj describe -m "feat: feature description" # Describe child commit
```

**Pro tip**: Split early and often. It's easier to combine commits later than to split them retrospectively.