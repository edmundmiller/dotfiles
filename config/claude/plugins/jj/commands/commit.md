---
allowed-tools: Bash(jj log:*), Bash(jj diff:*), Bash(jj commit:*), Bash(jj describe:*), Bash(jj new:*), Bash(jj status:*), Bash(jj file track:*)
argument-hint: [message]
description: Stack a commit with intelligent message generation
model: claude-haiku-4-5
---

!# Source utility scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../hooks/jj-state.sh"
source "$SCRIPT_DIR/../hooks/jj-templates.sh"
source "$SCRIPT_DIR/../hooks/jj-diff-context.sh"

!# Determine workflow state

# Check if current commit has a description

has_description=$(get_commit_state)

# Check if current commit is empty

is_empty=$(is_empty_commit)

!# Handle workflow logic

if [ "$is_empty" = "empty" ] && [ "$has_description" = "none" ]; then

# Empty commit with no description - need changes first

echo "ℹ️ **Current commit is empty with no description**"
echo ""
echo "Current: $(format_commit_short) (empty)"
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
else # Describe current commit using jj commit (describes @ and creates new working copy)
echo "📝 **Committing changes:** $ARGUMENTS"
    echo ""
    jj commit -m "$ARGUMENTS" 2>/dev/null || { # Fallback to describe if no changes
jj describe -m "$ARGUMENTS"
echo "💡 **Tip:** No changes to commit, description updated"
}
echo "✅ **Committed and created new working copy**"
fi
exit 0
fi

## Context

- Status: !`jj status`
- Changes: !`get_diff_stats`

## Task

Create commit for changes above. New files already tracked.

**Workflow:**

- Has "plan:" description → Update with actual work: `jj commit -m "message"`
- Has other description → Stack new commit: `jj new -m "message"`
- Needs description → Commit changes: `jj commit -m "message"`

Use conventional commit (feat/fix/refactor/docs/test/chore), under 72 chars, `-m` flag.
Note: `jj commit` describes @ and creates new working copy in one command.

Result: !`format_commit_short`
