---
allowed-tools: Bash(jj log:*), Bash(jj diff:*), Bash(jj commit:*), Bash(jj describe:*), Bash(jj new:*), Bash(jj status:*), Bash(jj file track:*)
argument-hint: [message]
description: Stack a commit with intelligent message generation
model: claude-haiku-4-5
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
- Changes: !`jj diff -r @ --stat`

## Task

Create commit for changes above. New files already tracked.

**Workflow:**

- Has "plan:" description → Update with actual work: `jj commit -m "message"`
- Has other description → Stack new commit: `jj new -m "message"`
- Needs description → Commit changes: `jj commit -m "message"`

Use conventional commit (feat/fix/refactor/docs/test/chore), under 72 chars, `-m` flag.
Note: `jj commit` describes @ and creates new working copy in one command.

Result: !`jj log -r @ -T 'concat(change_id.short(), ": ", description)' --no-graph`
