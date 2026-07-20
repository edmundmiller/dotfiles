---
name: using-jj-workspaces
description: Starts isolated jj agent workspaces with durable run receipts and handles Git-worktree boundaries.
---

# Using jj workspaces

Use the deterministic launcher instead of hand-building agent workspaces.

## Start

From a jj repository:

```bash
hey agent-start \
  --repo "$PWD" \
  --workspace "../workspaces/my-task" \
  --base 'trunk()' \
  --task my-task \
  --runtime pi \
  --model gpt-5
```

The command creates an isolated workspace and prints one JSON receipt. Save its `receiptPath` for `done`. Without `--workspace`, it records the current workspace.

The launcher:

- detects jj from live repository state;
- creates the workspace parent but never overwrites an existing destination;
- records stable change/operation IDs under `${XDG_STATE_HOME:-~/.local/state}/dotfiles-agent-runs/`;
- refuses to initialize jj inside a Git-only checkout or Codex Git worktree.

## Codex boundary

Codex desktop creates Git worktrees before the agent starts. Do not run `jj git init --colocate` inside that worktree: nested metadata would not convert the primary repository safely. Finish that task with Git. Initialize jj once from the primary checkout in a separate task; later agents can use jj workspaces from that repository.

## Workspace model

- Each workspace has its own working-copy commit `@`.
- Workspaces share commit history and the operation log.
- Mutating one workspace's `@` does not directly move another workspace's `@`.
- Repository-wide operation recovery can still affect concurrent work. Inspect `jj op log` and coordinate before `jj undo` or `jj op restore`.

Stay on one task per workspace. Read other changes with `jj diff -r`, `jj file show -r`, and `jj log -r`; do not use `jj edit` merely to inspect.

## Verify

```bash
jj workspace list
jj status
jj log -r '@-::@ | trunk()'
```

Run the repository's baseline checks before editing. If they fail, record the failure in the receipt/worklog and do not attribute it to the task.

## Finish

Use the global `done` skill. It shapes the task, rebases only its explicit range, publishes the default bookmark, proves remote equality, records the receipt, and cleans this workspace last.
