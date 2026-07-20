---
purpose: Teach the supported isolated jj workflow for coding agents.
applies_to: Agent tasks in repositories already initialized with jj.
entrypoint: Start with hey agent-start and finish with the global done skill.
verification: jj workspace list, receipt JSON, and verify-jj-landing.sh.
update_when: Workspace, receipt, policy, or landing behavior changes.
---

# Using jj with coding agents

## Mental model

jj snapshots tracked files automatically; there is no staging area. Each workspace has its own working-copy change `@`. Workspaces share history and the operation log, so repository-wide recovery still requires coordination.

Use stable change IDs to identify task work. Commit IDs may change after rebases or sign-on-push.

## Start isolated

```bash
hey agent-start \
  --repo "$PWD" \
  --workspace "../workspaces/my-task" \
  --base 'trunk()' \
  --task my-task \
  --runtime pi \
  --model gpt-5
```

Retain the JSON `receiptPath`. The launcher refuses to initialize jj inside a Codex-created Git worktree; finish that task with Git and initialize jj later from the primary checkout.

## Work

```bash
jj status
jj diff
jj describe -m "feat: concise intent"
jj new
```

Use one task per workspace. Inspect other revisions without moving `@`:

```bash
jj log -r <revision>
jj diff -r <revision>
jj file show -r <revision> path/to/file
```

Do not use Git mutation commands. Do not use `jj edit` merely to inspect.

## Recover narrowly

Start with `jj restore` for files or explicit revisions. Inspect `jj op log` for provenance. Coordinate before `jj undo` or `jj op restore`: those operations can affect shared repository state and concurrent workspaces.

## Finish

Invoke `done`. It records the task change ID, reconciles only that task range with the fresh remote destination, moves the default bookmark, publishes through jj, fetches again, proves authoritative remote equality, completes the receipt, and cleans the task workspace last.

Raw `git push` and `jj_vcs align_push` are blocked because they can report success without satisfying this proof contract.
