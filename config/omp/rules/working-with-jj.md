---
name: working-with-jj
description: Keep Herdr, jj, and Hunk work isolated and rooted correctly.
stable: true
condition: "(?m)(?:^|[;&|]\\s*)(?:(?:HERDR_ENV=\\S+\\s+)?hey\\s+agent-start|herdr\\b|hunk\\b|jj\\b|git\\s+(?:add|commit|reset|checkout|switch|rebase|merge|push)\\b)"
scope: "tool:bash"
---

## Working with Herdr, jj, and Git

Before mutating version control, run `jj root --ignore-working-copy` and load
`herdr-jj-workflow` when it succeeds.

- In jj, use jj commands; it snapshots automatically. Do not stage or commit
  with Git.
- A Codex Desktop Git worktree stays on Git. Never initialize jj inside it.
- When `HERDR_ENV=1`, use the current Herdr session; never launch a nested one.
- Run Hunk only from a Git root. Use read-only jj commands for inspection.
- Use `done` for authorized publication and cleanup; it proves remote equality.
