---
name: herdr-jj-workflow
description: Runs Herdr task workspaces with the selected agent, jj, Hunk, and durable receipts from creation through cleanup. Use for creating, resuming, reviewing, publishing, shipping, or removing a Herdr jj task workspace.
---

# Herdr + jj task workflow

Use one durable Herdr workspace per issue, PR, or task. Share one stable name across the checkout, jj workspace, jj bookmark, Herdr workspace label, and PR head:

- `issue-N-slug`
- `pr-N-slug`
- `task-slug`

Treat that name as durable. Treat Herdr workspace, tab, and pane IDs as live handles; re-read them after lifecycle changes.

Use Hunk from the task checkout's own Git root. For a non-colocated jj workspace, use `jj diff --git -r @` in the agent pane and record findings plus check output in the worklog when present, otherwise in the final handoff. "Review surface" below means either path.

## When to use

Use this skill for `create`, `resume`, `approve commit`, `publish`, `ship`, `submit review`, `cleanup`, or `abandon` requests involving a Herdr jj task workspace.

## Non-negotiable rules

1. Before controlling Herdr, require `HERDR_ENV=1`; use the current session and never launch nested Herdr.
2. Before any jj mutation, run `pwd` and `jj log -r @`. Never use `jj edit` only to inspect history.
3. Keep one task bookmark per workspace. Reuse it; do not create a replacement branch.
4. Shape the current change in place with `jj describe` and `jj squash`. Run `jj new` only when starting another reviewed intent.
5. Review every intended commit. Use Hunk from the Git root when available; otherwise use the pure-jj review surface defined above. Commit only after the user says `approve commit` and findings plus checks are clear.
6. In non-colocated jj workspaces, review in the agent pane; never point Hunk at the primary checkout or another workspace to work around a missing Git root.
7. Fetch only during explicit `publish` or `ship`, never during workspace creation.
8. Never stop or kill Herdr. Use config reloads and read-only state checks.

## Create or resume

1. Use `prefix+a` to create a jj workspace. Enter the stable task name and base revision. Base defaults to `trunk()`; use a published parent bookmark for a stacked task.
2. Let Herdr create the workspace and bootstrap its tabs. Do not create another workspace from the new agent session.
3. Run `hey agent-start` without `--workspace` from the created checkout and retain its receipt. For work covered by `AGENT_WORKFLOW.md`, keep its required worklog too.
4. The dotfiles `dev` layout opens `$AGENT` first, then Hunk. Export `AGENT` as the agent executable name or path in the pane's shell environment, without arguments. There is no hard-coded OMP fallback. The layout does not conditionally omit Hunk for non-colocated workspaces; use the agent pane for review there.
5. Use `herdr agent list` and `herdr workspace list` to resolve current live handles; never reuse example IDs.
6. Use `prefix+g` only for the native Git-only worktree flow.
7. Resume from the issue or PR, jj log/bookmarks, review findings, the run receipt, any worklog, and live Herdr state. Conversation history is not authoritative.

### Colocated child workspaces

With jj 0.46 or newer, `jj workspace add` creates a corresponding Git worktree when the source workspace is colocated and `git.colocate` is true, its default. The Herdr plugin uses this default without an override. Children created from a colocated child inherit the same behavior. No separate `git worktree add` or jj initialization is needed.

After creation, run these inside the child checkout:

```bash
jj root --ignore-working-copy
git rev-parse --show-toplevel
```

Both must resolve to the child checkout before using Hunk. Keep VCS mutations in jj and retain the explicit task bookmark; colocation does not make the task a Git-only workflow.

Existing non-colocated jj children do not change automatically. To convert one, first confirm its jj root, run `pwd` and `jj log -r @`, then run `jj git colocation enable` inside that child. Recheck both roots and reopen Hunk there. Do not create a replacement workspace. If keeping the child non-colocated, review with `jj diff --git -r @` in the agent pane. Manual creation can force either mode with `jj workspace add --colocate` or `--no-colocate`.

This conversion applies only to an existing jj workspace. Never run `jj git init --colocate` inside a Git-only worktree created by Codex or Herdr's native Git flow.

## Review and commit

1. Inspect `jj diff` and the current task bookmark.
2. Refresh the review surface: Hunk from `git rev-parse --show-toplevel`, or `jj diff --git -r @` for pure jj.
3. Address every applicable finding and run the focused check.
4. On `approve commit`, re-read the same review surface and check output.
5. Run `jj describe -m '<message>'`.
6. Run `jj bookmark set <task-name> -r @`.
7. If another independent intent remains, run `jj new`; otherwise leave `@` at the reviewed task tip.

## Publish

On explicit `publish`:

1. Verify any stacked parent is reviewed, pushed, and has a PR.
2. Run `jj git fetch`.
3. Rebase only the task stack: `jj rebase -b <task-name> -o <base>`.
4. Resolve conflicts, rerun focused checks, and refresh the review surface.
5. Run `jj bookmark set <task-name> -r @` and `jj git push --bookmark <task-name>`.
6. Create or update the PR. A stacked PR targets its parent bookmark; otherwise it targets the repository default branch.

## Ship

On explicit `ship`, verify recorded review approval and CI, then enable auto-merge. Ask before changing code to fix CI. After a parent PR merges, rebase and retarget each child from its own workspace.

## Cleanup and abandon

- `prefix+d` removes only a clean secondary workspace whose PR is closed or merged.
- `prefix+D` is the explicit abandon path. It still requires a clean workspace and exact typed task-name confirmation.
- Never remove the main jj workspace. Never clean up work that is changed, ambiguous, or still under an open PR.
- Keep the plugin's guarded cleanup. Its `jj workspace forget` also unregisters the corresponding Git worktree before directory removal. Do not bypass it with `git worktree remove` or an unguarded `jj workspace remove`.

## External PR review

Use `pr-N-slug`. Stay read-only by default. Put findings in the active review surface and submit them upstream only on explicit `submit review`. Modify the PR only after explicit takeover.
