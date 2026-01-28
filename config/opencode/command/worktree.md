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

3. Run: `wms <branch>` to create a new tmux session with the worktree
   - Or with prompt file: create worktree first with `workmux add <branch> -b`, then `wms <branch>`

4. Confirm the worktree was created and agent started

The agent runs in a separate tmux session. Monitor via `wmsl` (list sessions) or `tmux switch-client -t <branch>`.
