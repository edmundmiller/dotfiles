# jj

Applies when `jj root --ignore-working-copy` succeeds.

- Use jj commands; jj snapshots automatically. Do not stage or commit with Git.
- A Codex Desktop Git worktree stays on Git. Never initialize jj inside it.
- Use read-only jj commands for inspection. Run Hunk only from a Git root.
- When `HERDR_ENV=1`, use the current Herdr session; never launch a nested one.
  For Herdr task workspaces, load `herdr-jj-workflow`.
- Use `done` for authorized publication and cleanup; it proves remote equality.
