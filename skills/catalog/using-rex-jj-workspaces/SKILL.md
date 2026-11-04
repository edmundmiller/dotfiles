---
name: using-rex-jj-workspaces
description: Creates, resumes, reviews, and closes jj task workspaces in Rex. Use for Rex-based jj work, including task sessions opened by its workspace actions.
---

# Using Rex jj workspaces

Rex is the daily workspace UI. jj owns checkouts and bookmarks. Load the `rex`
skill for the installed CLI guide before manipulating sessions or panes.

## Start or resume

Run on the machine holding the checkout, against its local Rex server.
Confirm `jj root --ignore-working-copy`. Keep Git-only worktrees Git-only;
never initialize nested jj metadata to satisfy this workflow.

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

## Work and review

Keep one task per workspace. Use jj for VCS mutations, including in colocated
children. Read other changes with `jj diff -r`, `jj file show -r`, and `jj log`;
do not move `@` merely to inspect. Coordinate repository-wide operation undo.

Run baseline checks and record unrelated failures. Review with `rex-jj review
PATH`. Hunk is used only when both `jj root --ignore-working-copy` and
`git rev-parse --show-toplevel` identify that checkout. Otherwise the helper
prints a jj diff snapshot. Open a fresh review after editing.

With jj 0.46, colocated sources normally produce colocated children. Existing
non-colocated children need `jj git colocation enable` from the verified child
root before Hunk can use them. Never substitute `jj git init` for conversion.

Before publication, review the task range, run the repository's checks, and
record findings and verification with the receipt. Creation grants no push,
PR, merge, deployment, or cleanup authority. Use the `done` skill for an
authorized closeout and publish only the task's explicit bookmark. Re-read
live Rex IDs after lifecycle changes; task names and receipts are durable.

## Close safely

Closing a Rex session stops its terminals, but preserves its checkout and
bookmark. Stop only the task's processes, with authority; keep unrelated
sessions and the primary checkout.

Before removing a workspace, require explicit cleanup authority, no unreviewed
working-copy diff, and proof that every task commit is preserved remotely or
in the merged destination. Confirm the task PR is closed or merged. A clean
working-copy diff alone does not prove that unpublished commits are safe.
Intentional abandonment needs the exact task name confirmed by the user.

Use the `done` skill's guarded jj cleanup from a surviving workspace. Verify
the exact registered path and workspace name before `jj workspace forget` and
directory removal. Check the workspace list and, for colocated children, the
Git worktree list afterward. Close the exact Rex session last. If that is your
own session, report the result before closing it.
