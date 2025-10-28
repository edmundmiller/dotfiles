---
allowed-tools: Bash(jj log:*), Bash(jj diff:*), Bash(jj describe:*), Bash(jj new:*), Bash(jj status:*)
argument-hint: [message]
description: Stack a commit with intelligent message generation
---

!# Determine workflow state

# Check if current commit has a description

has_description=$(jj log -r @ --no-graph -T 'if(description, "has", "none")')

# Check if current commit is empty

is_empty=$(jj log -r @ --no-graph -T 'if(empty, "empty", "has_changes")')

!# Handle workflow logic

if [ "$is_empty" = "empty" ] && [ "$has_description" = "none" ]; then

# Empty commit with no description - need changes first

echo "ℹ️ **Current commit is empty with no description**"
echo ""
jj log -r @ -T 'concat("Current: ", change_id.short(), " (empty)")' --no-graph
echo ""
echo "💡 **Tip:** Make some changes first, then use \`/jj:commit\` to describe and stack"
exit 0
fi

!# Track any untracked files before committing

jj file track . 2>/dev/null || true

!# Determine action based on user argument

if [ -n "$ARGUMENTS" ]; then

# User provided explicit message - use it directly

if [ "$has_description" = "has" ]; then # Current commit already described, create new on top
echo "📦 **Creating new commit:** $ARGUMENTS"
    echo ""
    jj new -m "$ARGUMENTS" 2>/dev/null || true
echo "✅ **New commit created, ready for changes**"
else # Describe current commit
echo "📝 **Describing current commit:** $ARGUMENTS"
    echo ""
    jj describe -m "$ARGUMENTS"
echo "✅ **Commit described**"
echo ""

    # Auto-create new commit on top if described commit has changes
    if [ "$is_empty" = "has_changes" ]; then
      echo "📦 **Creating new empty commit for next work...**"
      echo ""
      jj new 2>/dev/null || true
      echo "✅ **Ready for next changes**"
    else
      echo "💡 **Tip:** Current commit is empty, make changes to continue"
    fi

fi
exit 0
fi

## Context

- Current status: !`jj status`
- Current changes: !`jj diff -r @`
- Recent commits: !`jj log -r 'ancestors(@, 5)' -T 'concat(change_id.short(), ": ", description)' --no-graph`
- Current state: !`jj log -r @ --no-graph -T 'if(description, "has description", "needs description")'`

## Your Task

Based on the above changes, create a commit in this jujutsu repository.

**Note:** Untracked files are automatically tracked before committing, so new files will be included in the commit.

**Plan-Driven Workflow:**

1. **Plan created** (UserPromptSubmit): If this is a substantial task, a "plan:" commit was created describing intent
2. **Work done**: Now you're here, work has been completed
3. **Describe reality**: Replace the plan with what actually happened

**Workflow:**

- If current commit has description starting with "plan:" → Update it with actual work done using `jj describe -m "message"`
- If current commit has other description → use `jj new -m "message"` to create new commit on top
- If current commit needs description → use `jj describe -m "message"` to describe current commit, then automatically `jj new` (unless commit is empty)

**TodoWrite Integration:**

- If you created a todo list, complete each todo then use `jj new` to move to next commit
- This creates a commit per major step in the work

**Conventional Commit Types:**

- `feat(scope):` new features
- `fix(scope):` bug fixes
- `docs(scope):` documentation
- `refactor(scope):` code restructuring
- `test(scope):` tests
- `chore(scope):` maintenance

**Guidelines:**

- Be specific about WHAT changed and WHY (not just which files)
- Keep first line under 72 characters
- Use heredoc for multi-line: `jj describe -m "$(cat <<'EOF' ... EOF)"`
- Match style of recent commits
- Always use `-m` flag (never open editor)

Show result: !`jj log -r @ -T 'concat(change_id.short(), ": ", description)' --no-graph`
