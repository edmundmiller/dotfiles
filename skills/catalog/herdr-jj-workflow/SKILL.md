---
name: herdr-jj-workflow
description: Runs issue, PR, and task work with Herdr, raw jj, OMP, and Hunk from creation through cleanup.
---

# Herdr + jj task workflow

Use one durable Herdr workspace per issue, PR, or task. The checkout, jj workspace, jj bookmark, Herdr workspace, and PR head share one stable name:

- `issue-N-slug`
- `pr-N-slug`
- `task-slug`

## When to use

Use this skill for `create`, `resume`, `approve commit`, `publish`, `ship`, `submit review`, `cleanup`, or `abandon` requests involving a Herdr task workspace.

## Non-negotiable rules

1. Before any jj mutation, run `pwd` and `jj log -r @`. Never use `jj edit` just to inspect history.
2. Keep one task bookmark per workspace. Reuse it; do not create a replacement branch.
3. Shape the current change in place with `jj describe` and `jj squash`. Run `jj new` only when starting another reviewed intent.
4. Hunk must review every intended commit. Commit only after the user says `approve commit` and the latest Hunk comments and checks are clear.
5. Fetch only during explicit `publish` or `ship`, never during workspace creation.
6. Never stop or kill Herdr. Use config reloads and read-only state checks.

## Create or resume

- `prefix+a`: create a jj workspace. Enter the stable task name and base revision. Base defaults to `trunk()`; use a published parent bookmark for a stacked task.
- `prefix+g`: Git-only fallback using Herdr's native worktree flow.
- A created checkout must contain exactly two tabs: `omp` and `hunk`, with `omp` focused.
- Resume from the issue or PR, jj log/bookmarks, Hunk comments, and Herdr state. Conversation history is not authoritative.

## Review and commit

1. Inspect `jj diff` and the current task bookmark.
2. Open or refresh Hunk for the intended change.
3. Address every applicable Hunk comment and run the focused check.
4. On `approve commit`, re-read Hunk and check output.
5. Run `jj describe -m '<message>'`.
6. Run `jj bookmark set <task-name> -r @`.
7. If another independent intent remains, run `jj new`; otherwise leave `@` at the reviewed task tip.

## Publish

On explicit `publish`:

1. Verify any stacked parent is reviewed, pushed, and has a PR.
2. Run `jj git fetch`.
3. Rebase only the task stack: `jj rebase -b <task-name> -o <base>`.
4. Resolve conflicts, rerun focused checks, and refresh Hunk.
5. Run `jj bookmark set <task-name> -r @` and `jj git push --bookmark <task-name>`.
6. Create or update the PR. A stacked PR targets its parent bookmark; otherwise it targets the repository default branch.

## Ship

On explicit `ship`, verify Hunk approval and CI, then enable auto-merge. Ask before changing code to fix CI. After a parent PR merges, rebase and retarget each child from its own workspace.

## Cleanup and abandon

- `prefix+d` removes only a clean secondary workspace whose PR is closed or merged.
- `prefix+D` is the explicit abandon path. It still requires a clean workspace and exact typed task-name confirmation.
- Never remove the main jj workspace. Never clean up work that is changed, ambiguous, or still under an open PR.

## External PR review

Use `pr-N-slug`. Stay read-only by default. Put findings in Hunk and submit them upstream only on explicit `submit review`. Modify the PR only after explicit takeover.
