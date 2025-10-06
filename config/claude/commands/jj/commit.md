---
allowed-tools: Bash(jj log:*), Bash(jj diff:*), Bash(jj describe:*), Bash(jj new:*), Bash(jj workspace:*), Bash(jj status:*)
argument-hint: [message]
description: Stack a commit and prepare for next change
model: claude-sonnet-4-20250514
---

!# Smart commit stacking in current workspace

# Check if current commit has a description
has_description=$(jj log -r @ --no-graph -T 'if(description, "has", "none")')

# Check if current commit is empty
is_empty=$(jj log -r @ --no-graph -T 'if(empty, "empty", "has_changes")')

# Determine action based on state
if [ "$has_description" = "has" ]; then
  # Current commit already has description, create new one on top
  if [ -z "$ARGUMENTS" ]; then
    echo "📦 **Creating new commit on top of stack...**"
  else
    echo "📦 **Creating new commit:** $ARGUMENTS"
  fi
  echo ""

  # Create new commit
  if [ -z "$ARGUMENTS" ]; then
    jj new 2>/dev/null || true
  else
    jj new -m "$ARGUMENTS" 2>/dev/null || true
  fi

  echo "✅ **New commit created, ready for changes**"
  echo ""
  echo "**Previous commit:**"
  jj log -r @- -T 'concat(change_id.short(), ": ", description)' --no-graph
  echo ""
  echo "**Current commit:**"
  jj log -r @ -T 'concat(change_id.short(), ": ", if(description, description, "(no description set)"))' --no-graph

elif [ "$is_empty" = "empty" ] && [ "$has_description" = "none" ]; then
  # Empty commit with no description - need changes first
  echo "ℹ️  **Current commit is empty with no description**"
  echo ""
  jj log -r @ -T 'concat("Current: ", change_id.short(), " (empty)")' --no-graph
  echo ""
  echo "💡 **Tip:** Make some changes first, then use \`/jj:commit\` to describe and stack"

else
  # Current commit needs a description
  # Auto-generate commit message if not provided
  if [ -z "$ARGUMENTS" ]; then
    echo "🤖 **Auto-generating commit message from changes...**"
    echo ""

    # Get file list and analyze
    files_json=$(jj log -r @ -T 'files.map(|f| f.path()).join("\n")' --no-graph 2>/dev/null || echo "")

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
    echo "📝 **Describing current commit:** $ARGUMENTS"
    echo ""
    jj describe -m "$ARGUMENTS"
  fi

  echo "✅ **Commit described**"
  echo ""
  echo "**Current commit:**"
  jj log -r @ -T 'concat(change_id.short(), ": ", description)' --no-graph
  echo ""
  echo "💡 **Tip:** Use \`/jj:commit\` again to create a new commit on top"
fi
