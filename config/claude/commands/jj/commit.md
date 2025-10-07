---
allowed-tools: Bash(jj log:*), Bash(jj diff:*), Bash(jj describe:*), Bash(jj new:*), Bash(jj workspace:*), Bash(jj status:*)
argument-hint: [message]
description: Stack a commit with intelligent message generation
model: claude-sonnet-4-20250514
---

!# Determine workflow state

# Check if current commit has a description
has_description=$(jj log -r @ --no-graph -T 'if(description, "has", "none")')

# Check if current commit is empty
is_empty=$(jj log -r @ --no-graph -T 'if(empty, "empty", "has_changes")')

!# Handle workflow logic

if [ "$is_empty" = "empty" ] && [ "$has_description" = "none" ]; then
  # Empty commit with no description - need changes first
  echo "ℹ️  **Current commit is empty with no description**"
  echo ""
  jj log -r @ -T 'concat("Current: ", change_id.short(), " (empty)")' --no-graph
  echo ""
  echo "💡 **Tip:** Make some changes first, then use \`/jj:commit\` to describe and stack"
  exit 0
fi

!# Determine action based on user argument

if [ -n "$ARGUMENTS" ]; then
  # User provided explicit message - use it directly
  if [ "$has_description" = "has" ]; then
    # Current commit already described, create new on top
    echo "📦 **Creating new commit:** $ARGUMENTS"
    echo ""
    jj new -m "$ARGUMENTS" 2>/dev/null || true
    echo "✅ **New commit created, ready for changes**"
  else
    # Describe current commit
    echo "📝 **Describing current commit:** $ARGUMENTS"
    echo ""
    jj describe -m "$ARGUMENTS"
    echo "✅ **Commit described**"
    echo ""
    echo "💡 **Tip:** Use \`/jj:commit\` again to create a new commit on top"
  fi
  exit 0
fi

## Context for Claude

Below is the current state of your jujutsu repository. Analyze the changes and create an appropriate commit message.

### Current Status
!`jj status`

### Current Changes
!`jj diff -r @`

### Recent Commits (for context and style)
!`jj log -r 'ancestors(@, 5)' -T 'concat(change_id.short(), ": ", description)' --no-graph`

### Current Commit State
!`jj log -r @ -T 'concat("Change ID: ", change_id.short(), "\nDescription: ", if(description, description, "(none)"), "\nFiles: ", files.map(|f| f.path()).join(", "))'  --no-graph`

---

## Your Task

Based on the above changes, you need to create a commit in this jujutsu repository.

**Workflow Decision:**
- Current commit state: !`jj log -r @ --no-graph -T 'if(description, "has description", "needs description")'`
- If current commit already has a description: Use `jj new -m "message"` to create a new commit on top
- If current commit needs description: Use `jj describe -m "message"` to describe the current commit

**Commit Message Guidelines:**

Analyze the changes carefully and determine the appropriate conventional commit type:
- `feat:` for new features or capabilities
- `fix:` for bug fixes
- `docs:` for documentation changes
- `style:` for formatting changes (code style, not CSS)
- `refactor:` for code restructuring without behavior change
- `test:` for test additions/changes
- `chore:` for maintenance tasks, dependency updates, etc.
- `perf:` for performance improvements

For scoped commits, use the format: `type(scope): message`
- Example: `feat(nvim): add sidekick plugin configuration`
- Example: `fix(zsh): correct alias definition for git status`

**Message Quality:**
- Be specific about WHAT changed and WHY (not just WHICH files)
- Focus on the semantic meaning, not the mechanical changes
- Keep the first line under 72 characters
- Add bullet points in the body if multiple distinct changes
- Look at recent commits for style consistency

**Important:**
- Use the `-m` flag with a heredoc for multi-line messages:
  ```bash
  jj describe -m "$(cat <<'EOF'
  fix(nvim): Change sidekick toggle to Ctrl+Space

  - Avoid conflict with existing Ctrl+K keybinding
  - Provides more ergonomic access to sidekick panel
  EOF
  )"
  ```
- For single-line messages, use: `jj describe -m "type(scope): message"`
- Never run `jj describe` or `jj new` without the `-m` flag

After creating the commit, show the result with:
!`jj log -r @ -T 'concat(change_id.short(), ": ", description)' --no-graph`
