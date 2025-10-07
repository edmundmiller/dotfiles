---
allowed-tools: Bash(jj log:*), Bash(jj squash:*), Bash(jj workspace:*)
argument-hint: [revision]
description: Merge commits in the stack
model: sonnet
---

!# Squash (merge) commits

# Default: squash current @ into parent
# With revision: squash specific revision

if [ -n "$ARGUMENTS" ]; then
  echo "🔀 Squashing revision: **$ARGUMENTS**"
  echo ""
  jj squash -r "$ARGUMENTS" 2>&1 || {
    echo "❌ Failed to squash $ARGUMENTS"
    echo ""
    echo "**Available revisions:**"
    jj log -r ::@ --limit 5 -T '{change_id.short()}: {description}'
    exit 1
  }
else
  # Check if @ has changes
  has_changes=$(jj status --no-pager 2>/dev/null | grep -E "^[AM]" || echo "")

  if [ -z "$has_changes" ]; then
    echo "ℹ️  Current @ is empty, nothing to squash"
    echo ""
    echo "**Commit stack:**"
    jj log -r ::@ --limit 3 -T '{change_id.short()}: {description}'
    exit 0
  fi

  echo "🔀 Squashing current @ into parent..."
  echo ""
  jj squash 2>&1 || {
    echo "❌ Failed to squash"
    exit 1
  }
fi

echo ""
echo "✅ **Commits merged**"
echo ""
echo "**Updated stack:**"
jj log -r ::@ --limit 5 -T '{change_id.short()}: {description}'

echo ""
echo "💡 **Tip:** Continue with \`/jj:commit\` or use \`/jj:split\` to separate concerns"
