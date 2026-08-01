---
name: working-with-jj
description: Keep Herdr, jj, and Hunk work isolated and rooted correctly.
stable: true
condition: "\\b(?:HERDR_ENV|agent-start|herdr|hunk|jj|git\\s+(?:add|commit|reset|checkout|switch|rebase|merge|push))\\b"
scope: "tool:bash"
---

## Working with Herdr and jj

- When `HERDR_ENV=1`, use the current Herdr session; never launch nested Herdr. `prefix+a` creates the task jj workspace, then `hey agent-start` records that workspace without `--workspace`.
- Herdr bootstraps OMP in every workspace. It adds Hunk only when `git rev-parse --show-toplevel` succeeds; never launch Hunk from an arbitrary pane directory.
- Before choosing VCS commands, run `jj root --ignore-working-copy`. jj repositories snapshot automatically; never stage or commit them with Git.
- Agent-created Git worktrees, including Codex Desktop worktrees, stay on the Git backend. Never initialize nested jj metadata there.
- Keep one task bookmark per workspace. Record the stable change ID before landing; sign-on-push may change the commit ID.
- Never `jj edit` only to inspect. Use `jj diff -r`, `jj file show -r`, or `jj log -r`.
- Recover files with narrow `jj restore` operations first. Inspect `jj op log` and coordinate before repository-wide `jj undo` or `jj op restore`; concurrent workspaces share operations.
- Use the `done` skill for publication and cleanup. It proves bookmark and remote equality before removing the workspace.
