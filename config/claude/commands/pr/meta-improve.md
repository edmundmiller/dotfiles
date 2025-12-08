---
allowed-tools: Read, Edit, Glob, Grep
argument-hint: [pr-number]
description: Analyze completed PR review to improve future review workflows
---

## Context

- Review plan command location: !`ls -la ~/.config/claude/commands/pr/ 2>/dev/null || ls -la config/claude/commands/pr/ 2>/dev/null || echo "Commands not found"`
- Recent PR activity: !`gh pr list --state merged --limit 5 --json number,title,author,mergedAt 2>/dev/null || echo "No recent PRs"`

## Your Task

Run a **meta-improvement loop** on the PR review process. After conducting a review (using `/pr/review-plan`), this command helps analyze what worked and what didn't, then updates the review workflow.

**Key Principle:** "After each review, run a meta-prompt to improve your workflow."

### Step 1: Review Reflection

Ask the human about the just-completed review:

1. **What comments were most valuable?** Which observations actually helped?
2. **What was missed?** Any issues that slipped through?
3. **What was noise?** Comments that weren't helpful or were too nitpicky?
4. **Time spent:** Was the review efficient?

### Step 2: Analyze Patterns

Based on the reflection, identify:

**Effective Patterns:**
- Types of issues consistently caught
- File categories that needed most attention
- Questions that led to productive discussions

**Anti-Patterns:**
- False positives (flagged but not actual issues)
- Repeated nitpicks that don't add value
- Areas where AI analysis was less accurate than human judgment

### Step 3: Generate Improvements

Propose specific changes to the review workflow:

1. **Focus Area Adjustments**
   - Areas to emphasize more
   - Areas to de-emphasize
   - New categories to add

2. **Heuristic Updates**
   - Patterns that indicate real issues
   - Patterns that are usually fine
   - Context-specific rules for this codebase

3. **Efficiency Gains**
   - Steps that can be parallelized
   - Checks that can be automated vs need human judgment
   - Better ways to present findings

### Step 4: Update Review Command

If the human approves, update the `/pr/review-plan` command:

```bash
# Location of review-plan command
$DOTFILES/config/claude/commands/pr/review-plan.md
```

Propose specific edits:
- Add new focus areas to the checklist
- Remove or deprioritize unhelpful checks
- Add codebase-specific patterns
- Update severity guidelines

### Step 5: Document Learning

Create a brief summary for the human:

```
REVIEW SESSION SUMMARY
======================
PR: #<number>
Date: <date>

What Worked:
- <insight 1>
- <insight 2>

What to Improve:
- <improvement 1>
- <improvement 2>

Changes Made:
- <edit to review-plan.md>
```

### Important

- This is a **collaborative** improvement process - always ask before making changes
- Focus on **patterns**, not one-off issues
- Keep the review command lean - don't add checks that rarely provide value
- The goal is to make future reviews faster AND more effective
