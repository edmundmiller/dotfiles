---
name: using-jj-workspaces
description: Creates or records isolated jj agent workspaces. Use when starting jj task work, entering a Rex or Herdr workspace, or handling an agent-created Git worktree boundary.
---

# Using jj workspaces

Choose one workspace owner; never create a second workspace for the same task.

## Start

First confirm the current checkout is a jj repository:

```bash
jj root --ignore-working-copy
```

### Inside Rex

Use the `using-rex-jj-workspaces` skill. Rex is the daily driver; its `rex-jj`
helper owns creation and receipts. In a Rex-created task, read
`.jj/rex-session.json` and reuse its `receiptPath` instead of creating another
workspace. Keep Herdr's bindings and bootstrap out of Rex sessions.

### Inside Herdr

Let `prefix+a` create the task-named jj workspace and open its `$AGENT` tab. Export `AGENT` as the agent executable name or path in the pane's shell environment, without arguments. From that checkout, record the existing workspace without `--workspace`:

```bash
hey agent-start \
  --repo "$PWD" \
  --task my-task \
  --runtime "$AGENT"
```

Herdr's `dev` layout opens `$AGENT` first, then Hunk, without a Git-root condition or a hard-coded OMP fallback. With jj 0.46 or newer, children created from a colocated workspace are also colocated when `git.colocate` is true, its default. Hunk can then review the child checkout directly. Do not launch nested Herdr or create another jj workspace from the new agent session.

### Outside Herdr

Use the deterministic launcher to create and record the workspace:

```bash
hey agent-start \
  --repo "$PWD" \
  --workspace "../workspaces/my-task" \
  --base 'trunk()' \
  --task my-task \
  --runtime "$AGENT"
```

Both forms print one JSON receipt. Save its `receiptPath` for `done`. Without `--workspace`, the launcher records the current workspace.

The launcher:

- detects jj from live repository state;
- creates the workspace parent but never overwrites an existing destination;
- records stable change and operation IDs under `${XDG_STATE_HOME:-~/.local/state}/dotfiles-agent-runs/`;
- refuses to initialize jj inside a Git-only checkout or Codex Git worktree.

## Git worktree boundary

Agent runtimes such as Codex Desktop can create Git worktrees before the agent starts. Do not run `jj git init --colocate` inside one: nested metadata would not safely convert the primary repository. Finish that task with Git. Initialize jj once from the primary checkout in a separate task; later agents can use jj workspaces from that repository.

## Workspace model

- Each workspace has its own working-copy commit `@`.
- Workspaces share commit history and the operation log.
- Mutating one workspace's `@` does not directly move another workspace's `@`.
- Colocated children also have a Git worktree. Do not run a separate `git worktree add`; keep mutations in jj and retain the task bookmark.
- Repository-wide operation recovery can affect concurrent work. Inspect `jj op log` and coordinate before `jj undo` or `jj op restore`.
- In Herdr, task names are durable; workspace, tab, and pane IDs are live handles. Re-read them after lifecycle changes.
- Before using Hunk, confirm `jj root --ignore-working-copy` and `git rev-parse --show-toplevel` both resolve to this child checkout, not its primary workspace.
- Existing non-colocated jj children stay non-colocated. Follow `herdr-jj-workflow` to convert one in place with `jj git colocation enable`, or keep reviewing with `jj diff --git -r @` in the agent pane. Record findings plus check output in the worklog when present, otherwise in the final handoff.

Stay on one task per workspace. Read other changes with `jj diff -r`, `jj file show -r`, and `jj log -r`; do not use `jj edit` merely to inspect.

## Verify

```bash
jj workspace list
jj status
jj log -r '@-::@ | trunk()'
```

Run the repository's baseline checks before editing. If they fail, record the failure in the receipt/worklog and do not attribute it to the task.

## Finish

Use the global `done` skill. It shapes the task, rebases only its explicit range, publishes the task workspace's explicit bookmark, proves remote equality, records the receipt, and cleans this workspace last.
