---
allowed-tools: Bash(jj describe:*), Bash(jj new:*), Bash(jj squash:*), Bash(jj status:*), Bash(jj log:*), Bash(jj diff:*)
argument-hint: [step|message]
description: Complete squash workflow - Describe → New → Implement → Squash
model: claude-sonnet-4-20250514
---

## The Squash Workflow ⭐ **RECOMMENDED**

**Pattern**: Describe → New → Implement → Squash

This is the primary workflow for focused development. Perfect for AI-assisted coding.

## Current Status
!`jj status`
!`jj log -r ::@ --limit 4 --no-graph`

## Intelligent Workflow Guide

!# Check current state and guide accordingly
current_desc=$(jj log -r @ -T description --no-graph 2>/dev/null || echo "")
has_changes=$(jj status --no-pager 2>/dev/null | grep -E "^[AM]" || echo "")
parent_desc=$(jj log -r @- -T description --no-graph 2>/dev/null || echo "")

if [ "$ARGUMENTS" = "step1" ] || [ "$ARGUMENTS" = "describe" ]; then
  echo "### Step 1: Describe Your Intent"
  echo ""
  echo "Start by describing what you plan to build:"
  echo "\`\`\`bash"
  echo "jj describe -m \"feat: implement user authentication\""
  echo "\`\`\`"
  echo ""
  echo "**Why describe first?**"
  echo "- Sets clear intent before coding"
  echo "- Creates focused, well-scoped commits"
  echo "- Helps Claude understand the goal"
  echo ""
  echo "Ready for step 2? Use: \`@squash-workflow step2\`"
elif [ "$ARGUMENTS" = "step2" ] || [ "$ARGUMENTS" = "new" ]; then
  echo "### Step 2: Create New Empty Change"
  echo ""
  echo "Create a fresh workspace for implementation:"
  echo "\`\`\`bash"
  echo "jj new  # Creates empty change, moves working copy"
  echo "\`\`\`"
  echo ""
  echo "**What happens:**"
  echo "- Previous work (with description) is preserved"
  echo "- Working copy moves to new empty change"
  echo "- Ready for implementation"
  echo ""
  echo "Ready to implement? Use: \`@squash-workflow step3\`"
elif [ "$ARGUMENTS" = "step3" ] || [ "$ARGUMENTS" = "implement" ]; then
  echo "### Step 3: Implement Your Changes"
  echo ""
  echo "Now build what you described:"
  echo "- Write code, tests, documentation"
  echo "- Make multiple edits across files"
  echo "- Changes accumulate in current commit"
  echo ""
  echo "**Key insight:** Changes are safe in current commit until squashed"
  echo ""
  echo "Check progress: \`jj diff\` or \`jj status\`"
  echo ""
  echo "Ready to complete? Use: \`@squash-workflow step4\`"
elif [ "$ARGUMENTS" = "step4" ] || [ "$ARGUMENTS" = "squash" ]; then
  echo "### Step 4: Complete the Work"
  echo ""
  echo "Move your implementation into the described commit:"
  echo "\`\`\`bash"
  echo "jj squash  # Moves changes to parent commit"
  echo "\`\`\`"
  echo ""
  echo "**Options:**"
  echo "- \`jj squash\` - Move all changes"
  echo "- \`jj squash -i\` - Select specific changes interactively"
  echo "- \`jj squash -m \"updated message\"\` - Update commit message"
  echo ""
  echo "**Result:** Clean, focused commit ready for review/push"
elif [ "$ARGUMENTS" = "auto" ] || [ "$ARGUMENTS" = "next" ]; then
  if [ "$current_desc" = "(no description set)" ] || [ -z "$current_desc" ]; then
    echo "🎯 **Auto-guide: Need to describe your work**"
    echo ""
    echo "Start the squash workflow by describing what you'll build:"
    echo "\`\`\`bash"
    echo "jj describe -m \"feat: your feature description\""
    echo "\`\`\`"
    echo ""
    echo "Then continue with: \`@squash-workflow next\`"
  elif [ -z "$has_changes" ]; then
    echo "🎯 **Auto-guide: Ready for implementation**"
    echo ""
    echo "You have a described commit. Create workspace for implementation:"
    echo "\`\`\`bash"
    echo "jj new  # Creates empty change for implementation"
    echo "\`\`\`"
    echo ""
    echo "Then implement your changes and use: \`@squash-workflow next\`"
  else
    echo "🎯 **Auto-guide: Ready to complete**"
    echo ""
    echo "You have changes ready to squash into your described commit:"
    echo "\`\`\`bash"
    echo "jj squash  # Completes the workflow"
    echo "\`\`\`"
    echo ""
    echo "Parent commit: \`$parent_desc\`"
  fi
elif [ -n "$ARGUMENTS" ]; then
  echo "🚀 **Starting squash workflow with: $ARGUMENTS**"
  echo ""
  echo "I'll set this up for you:"
  jj describe -m "$ARGUMENTS"
  echo ""
  echo "Description set! Now create workspace for implementation:"
  echo "\`\`\`bash"
  echo "jj new  # Creates empty change for implementation"
  echo "\`\`\`"
  echo ""
  echo "After implementing, complete with: \`jj squash\`"
else
  echo "## Complete Workflow Example"
  echo ""
  echo "\`\`\`bash"
  echo "# 1. Describe what you're building"
  echo "jj describe -m \"feat: add user authentication\""
  echo ""
  echo "# 2. Create workspace for implementation"
  echo "jj new"
  echo ""
  echo "# 3. Implement (multiple files, multiple edits)"
  echo "# ... make your changes ..."
  echo ""
  echo "# 4. Complete the work"
  echo "jj squash"
  echo "\`\`\`"
  echo ""
  echo "### Step-by-step guidance:"
  echo "- \`@squash-workflow step1\` - Describe intent"
  echo "- \`@squash-workflow step2\` - Create workspace"
  echo "- \`@squash-workflow step3\` - Implementation tips"
  echo "- \`@squash-workflow step4\` - Complete work"
  echo ""
  echo "### Quick start:"
  echo "\`@squash-workflow \"your description\"\` - Begin with message"
fi

### Current changes ready for squash:
!`jj diff --summary`

**Remember**: This workflow creates focused, reviewable commits that tell a clear story.