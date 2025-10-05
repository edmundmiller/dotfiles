---
allowed-tools: Bash(jj log:*), Bash(jj diff:*), Bash(jj describe:*), Bash(jj new:*), Bash(jj workspace:*)
argument-hint: [message]
description: Stack a commit and prepare for next change
model: claude-sonnet-4-20250514
---

!# Stack a commit in current workspace

# Check if we have changes
has_changes=$(jj status --no-pager 2>/dev/null | grep -E "^[AM]" || echo "")

if [ -z "$has_changes" ]; then
  echo "ℹ️  No changes to commit"
  echo ""
  jj log -r @ -T 'Current: {change_id.short()}\nDescription: {description}\n' --no-graph
  exit 0
fi

# Auto-generate commit message if not provided
if [ -z "$ARGUMENTS" ]; then
  echo "🤖 Auto-generating commit message from changes..."
  echo ""

  # Get file list and analyze
  files_json=$(jj log -r @ -T '{files.map(f => f.path()).join("\n")}' --no-graph)

  # Detect commit type from patterns
  commit_type="chore"
  if echo "$files_json" | grep -qE "test|spec|\.test\.|\.spec\."; then
    commit_type="test"
  elif echo "$files_json" | grep -qE "\.md$|README|CHANGELOG|docs/"; then
    commit_type="docs"
  elif echo "$files_json" | grep -qE "fix|bug|patch"; then
    commit_type="fix"
  else
    file_count=$(echo "$files_json" | wc -l | tr -d ' ')
    if [ "$file_count" -gt 3 ]; then
      commit_type="feat"
    else
      commit_type="fix"
    fi
  fi

  # Generate message
  file_summary=$(echo "$files_json" | head -3 | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
  if [ $(echo "$files_json" | wc -l) -gt 3 ]; then
    file_summary="$file_summary, and more"
  fi

  commit_msg="$commit_type: update $file_summary"

  echo "**Generated:** \`$commit_msg\`"
  echo ""
  jj describe -m "$commit_msg"
else
  # Use provided message
  echo "📝 Commit message: **$ARGUMENTS**"
  echo ""
  jj describe -m "$ARGUMENTS"
fi

# Create new empty change on top (completes the commit)
jj new 2>/dev/null || true

echo ""
echo "✅ **Commit stacked, ready for next change**"
echo ""
echo "**Committed:**"
jj log -r @- -T '{change_id.short()}: {description}' --no-graph

echo ""
echo "💡 **Tip:** Make more commits with \`/jj:commit\`, merge with \`/jj:squash\`, or split concerns with \`/jj:split <pattern>\`"
