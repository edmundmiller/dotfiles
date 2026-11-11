# jj workspaces

Choose one workspace owner; never create a second workspace for the same task.
Confirm `jj root --ignore-working-copy` first. Keep Git-only worktrees Git-only;
never initialize nested jj metadata to satisfy this workflow.

## Start or resume in Rex

Rex is the daily workspace UI; jj owns checkouts and bookmarks. Load the `rex`
skill for the installed CLI guide before manipulating sessions or panes. Run on
the machine holding the checkout, against its local Rex server.

- Inside a task opened by Rex, reuse the current checkout and read
  `.jj/rex-session.json` for its session ID and `receiptPath`. Do not create a
  second workspace or receipt. Read the receipt before continuing the task.
- For a new task, run `rex-jj new issue-123-slug --repo PATH --base 'trunk()'`.
  Use the parent bookmark as the base for stacked work. The helper creates the
  workspace, task bookmark, receipt, and Rex session. `AGENT` must be one
  executable; use `--agent PATH` to override it, or a wrapper for flags.
- For an existing checkout, run `rex-jj open PATH`. It reuses a live session
  even after a rename, or opens one if the old session was closed.

`new` and `open` return JSON. Save the workspace, session ID, and receipt path.
CLI calls do not select a Mac app unless passed `--client CLIENT_ID`.
Use `rex client ls` to identify the intended client before selecting it.
If session creation fails, preserve the checkout and use the printed resume
path. Do not retry `new` or remove the checkout to clear an error.

The UI equivalents are Ctrl+C then `a` for creation, `Shift+A` for opening the
focused checkout, `d` for review, and `w` for session switching. Pi conversation
forks are separate and stay in the same checkout; they do not isolate edits.

## Start or resume in Herdr

Load `herdr-jj-workflow` for Herdr tasks, including review, commit approval,
publication, and cleanup. It owns the live session, task bookmark, and approval
gates. Check its backend routing first. Native uses `herdr-app`/`hc` and
`herdr-dev open PATH` for existing checkouts; do not launch the old TUI.
The `prefix+a` workspace lifecycle belongs only to the legacy backend.
Record an existing checkout with `hey agent-start` without `--workspace`;
do not create a second checkout or launch nested Herdr. Keep its guarded
cleanup and non-colocated review rules. Unsupported native lifecycle operations
stay deferred rather than bypassing their guards.

## Start outside Rex or Herdr

On machines with Edmund's dotfiles, use the deterministic launcher to create
and record the workspace:

```bash
hey agent-start \
  --repo "$PWD" \
  --workspace "../workspaces/my-task" \
  --base 'trunk()' \
  --task my-task \
  --runtime "$AGENT"
```

It prints one JSON receipt; save its `receiptPath` for `done`. Without
`--workspace`, it records the current workspace. The launcher detects jj from
live state, never overwrites an existing destination, records stable change
and operation IDs under `${XDG_STATE_HOME:-~/.local/state}/dotfiles-agent-runs/`,
and refuses to initialize jj inside a Git-only checkout or Codex Git worktree.

## Git worktree boundary

Agent runtimes such as Codex Desktop can create Git worktrees before the agent
starts. Do not run `jj git init --colocate` inside one: nested metadata would
not safely convert the primary repository. Finish that task with Git.
Initialize jj once from the primary checkout in a separate task.

## Workspace model

- Each workspace has its own working-copy commit `@`; workspaces share commit
  history and the operation log.
- Mutating one workspace's `@` does not directly move another workspace's `@`.
- Colocated children also have a Git worktree (see [jj](jj.md)). Do not run a
  separate `git worktree add`; keep mutations in jj and retain the task bookmark.
- Repository-wide operation recovery can affect concurrent work. Inspect
  `jj op log` and coordinate before `jj undo` or `jj op restore`.
- Task names and receipts are durable; session, tab, and pane IDs are live
  handles. Re-read them after lifecycle changes.

Stay on one task per workspace. Read other changes with `jj diff -r`,
`jj file show -r`, and `jj log -r`; do not move `@` merely to inspect.

## Work and review

```bash
jj workspace list
jj status
jj log -r '@-::@ | trunk()'
```

Run the repository's baseline checks before editing and record unrelated
failures in the receipt or worklog. In Rex, review with `rex-jj review PATH`;
it uses Hunk only when both `jj root --ignore-working-copy` and
`git rev-parse --show-toplevel` identify that checkout, and otherwise prints a
jj diff snapshot. Elsewhere, review non-colocated children with
`jj diff --git -r @`. Open a fresh review after editing.

Before publication, review the task range, run the repository's checks, and
record findings and verification with the receipt. Creation grants no push,
PR, merge, deployment, or cleanup authority.

## Finish and close

Use the `done` skill for an authorized closeout. It shapes the task, rebases
only its explicit range, publishes the task's explicit bookmark, proves remote
equality, records the receipt, and cleans this workspace last.
For Herdr tasks, retain `herdr-jj-workflow`'s commit approval gates and guarded
cleanup rather than applying Rex session operations.

Closing a Rex session stops its terminals but preserves its checkout and
bookmark. Stop only the task's processes, with authority; keep unrelated
sessions and the primary checkout.

Before removing a workspace, require explicit cleanup authority, no unreviewed
working-copy diff, and proof that every task commit is preserved remotely or in
the merged destination. Confirm the task PR is closed or merged. A clean
working-copy diff alone does not prove that unpublished commits are safe.
Intentional abandonment needs the exact task name confirmed by the user.

Use `done`'s guarded jj cleanup from a surviving workspace. Verify the exact
registered path and workspace name before `jj workspace forget` and directory
removal. Check the workspace list and, for colocated children, the Git worktree
list afterward. Close the exact Rex session last. If that is your own session,
report the result before closing it.
