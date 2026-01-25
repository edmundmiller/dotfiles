---
description: Delegate task to new worktree with background agent
---

Delegate a task to a new git worktree with a background AI agent.

Task to delegate: $ARGUMENTS

For this task:

1. Generate a concise kebab-case branch name (3-4 words max)

2. Create a detailed prompt file at `/tmp/workmux-<branch>.md` containing:
   - Clear task description
   - Required context (relevant files, APIs, patterns)
   - Expected deliverables
   - Any constraints or requirements
   - Reference to key files using @file syntax

3. Run: `workmux add <branch> -b -P /tmp/workmux-<branch>.md`

4. Confirm the worktree was created and agent started

The agent runs in the background. Monitor via `workmux dashboard` or check tmux windows.
