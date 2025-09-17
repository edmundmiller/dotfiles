---
allowed-tools: Bash(jj status:*), Bash(jj log:*), Bash(jj diff:*), Bash(jj branch:*)
description: Enhanced status with workflow context
model: claude-sonnet-4-20250514
---

## Repository Status with Context

Get a comprehensive view of your current state and suggested next actions.

## Current State
!`jj status`

## Change History Context
!`jj log -r ::@ --limit 5 --no-graph`

## Workflow Analysis

!# Analyze current state and provide guidance
current_desc=$(jj log -r @ -T description --no-graph 2>/dev/null || echo "")
has_changes=$(jj status --no-pager 2>/dev/null | grep -E "^[AM]" || echo "")
parent_desc=$(jj log -r @- -T description --no-graph 2>/dev/null || echo "")

echo "### Intelligent Status Analysis"
echo ""

if [ "$current_desc" = "(no description set)" ] || [ -z "$current_desc" ]; then
  if [ -n "$has_changes" ]; then
    echo "🔄 **You have changes but no description**"
    echo ""
    echo "**Recommended actions:**"
    echo "1. Describe your work: \`@describe \"what you're building\"\`"
    echo "2. Or start fresh: \`@squash-workflow \"your description\"\`"
    echo ""
    echo "**Current changes:**"
    echo "\`\`\`"
    jj diff --summary
    echo "\`\`\`"
  else
    echo "✅ **Clean working copy, ready for new work**"
    echo ""
    echo "**Recommended actions:**"
    echo "1. Start squash workflow: \`@squash-workflow \"feat: your description\"\`"
    echo "2. Or start edit workflow: \`@edit-workflow start\`"
    echo "3. Create simple change: \`@new \"description\"\`"
  fi
elif [ -n "$has_changes" ]; then
  echo "🚧 **In progress: Implementation phase**"
  echo ""
  echo "**Current work:** \`$current_desc\`"
  echo "**Parent commit:** \`$parent_desc\`"
  echo ""
  echo "**Ready to complete? Options:**"
  echo "1. Squash all changes: \`jj squash\`"
  echo "2. Interactive squash: \`jj squash -i\`"
  echo "3. Continue guided workflow: \`@squash-workflow next\`"
  echo ""
  echo "**Current changes:**"
  echo "\`\`\`"
  jj diff --summary
  echo "\`\`\`"
else
  echo "📝 **Described but not implemented**"
  echo ""
  echo "**Current work:** \`$current_desc\`"
  echo ""
  echo "**Ready for implementation:**"
  echo "1. Create workspace: \`jj new\`"
  echo "2. Or guided workflow: \`@squash-workflow step2\`"
  echo "3. Start implementing your described changes"
fi

## Recent Operations
!echo ""
echo "### Recent Operations (undoable)"
jj op log --limit 3

## Branches
!echo ""
echo "### Branch Status"
jj branch list

## Quick Actions

Based on your current state, here are the most relevant commands:

### Workflow Commands:
- `@squash-workflow` - Complete squash workflow guidance
- `@edit-workflow` - Advanced multi-commit workflow
- `@squash` - Complete current work
- `@describe` - Add/update commit message

### Navigation:
- `@navigate` - Move between changes
- `@undo` - Undo last operation

### Safety:
- `jj op log` - See all operations (everything is undoable)
- `jj diff` - See current changes
- `jj show` - Review current commit

**Remember**: Every operation in jj is undoable. Use `@undo` or `jj op restore` for safety.