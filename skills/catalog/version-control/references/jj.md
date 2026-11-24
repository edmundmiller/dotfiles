# jj

Applies when `jj root --ignore-working-copy` succeeds.

- Use jj commands; jj snapshots automatically. Do not stage or commit with Git.
- A Codex Desktop Git worktree stays on Git. Never initialize jj inside it.
- Use read-only jj commands for inspection. Run Hunk only from a Git root.
- Shape the current change in place with `jj describe` and `jj squash`. Run
  `jj new` only when starting another intent. Never `jj edit` just to inspect.
- Use `done` for authorized publication and cleanup; it proves remote equality.

## Commit some paths from a dirty working copy

```bash
jj new main@origin --no-edit -m "<message>"   # prints the new change ID
jj restore --from @ --into <rev> <paths>
jj diff --stat -r <rev>                       # must list every intended file
```

`snapshot.auto-track` can leave new files untracked without a warning, so the
restore skips them. If the stat misses a file, run `jj file track <path>` and
restore again. Unlisted paths stay in the working copy.

## Colocated workspaces

With jj 0.46 or newer, `jj workspace add` from a colocated workspace also
creates a Git worktree (`git.colocate` defaults to true). Before using Hunk or
other Git tools in a child, both of these must resolve to the child checkout:

```bash
jj root --ignore-working-copy
git rev-parse --show-toplevel
```

Existing non-colocated children stay that way. To convert one, confirm its jj
root, run `pwd` and `jj log -r @`, then `jj git colocation enable` inside it.
Otherwise review with `jj diff --git -r @`. Never run `jj git init --colocate`
inside a Git-only worktree.
