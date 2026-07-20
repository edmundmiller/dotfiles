---
name: working-with-jj
description: Keep agent work isolated and recoverable in jj repositories.
stable: true
condition: "\\b(?:jj|git\\s+(?:add|commit|reset|checkout|switch|rebase|merge|push))\\b"
scope: "tool:bash"
---

## Working with jj

- Start isolated work with `hey agent-start --repo "$PWD" --workspace <path> --task <id>`. Codex Git worktrees stay on the Git backend; never initialize nested jj metadata there.
- `@` is local to this workspace. The repository history and operation log are shared.
- Never `jj edit` only to inspect. Use `jj diff -r`, `jj file show -r`, or `jj log -r`.
- Do not stage or commit with Git in a jj repository. jj snapshots automatically; use `jj diff`, `jj describe`, `jj new`, and explicit bookmarks.
- Use one task per workspace. Record the stable change ID before landing; sign-on-push may change the commit ID.
- Recover files with narrow `jj restore` operations first. Inspect `jj op log` and coordinate before repository-wide `jj undo` or `jj op restore` because concurrent workspaces share operations.
- Use the `done` skill for publication. It verifies local bookmark, tracked remote bookmark, and authoritative remote equality before cleanup.
