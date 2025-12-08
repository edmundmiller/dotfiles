---
allowed-tools: Read, Edit
description: Improve the PR review prompt based on recent review experience
---

## Your Task

In light of the back and forth in this chat, edit the PR review prompt to reflect anything that might help future PR review plans get to a good place sooner.

### Instructions

1. **Read the current PR review command:**
   Read the file at `config/claude/plugins/github/commands/pr-review.md`

2. **Analyze the conversation:**
   - What friction points occurred during the review?
   - What additional context would have been helpful upfront?
   - Were there steps that could be combined or reordered?
   - Did any assumptions prove incorrect?
   - What edge cases weren't handled?

3. **Identify improvements:**
   - Missing steps or checks
   - Better default behaviors
   - Clearer instructions for ambiguous situations
   - Additional gh CLI commands that would help
   - Better formatting for comments or summaries

4. **Update the prompt:**
   Edit the pr-review.md file with your improvements.

5. **Summarize changes:**
   Provide a brief summary of what was changed and why.

### Guidelines

- Keep the 6-step structure unless there's a compelling reason to change it
- Preserve working patterns - only modify what needs improvement
- Add comments explaining non-obvious decisions
- Consider both simple PRs and complex multi-file changes
- Ensure gh CLI commands remain correct and up-to-date

### Example Improvements

- "Added a step to check CI status before reviewing"
- "Clarified how to handle PRs with merge conflicts"
- "Added draft PR detection to avoid reviewing unfinished work"
- "Improved comment formatting for multi-line suggestions"
