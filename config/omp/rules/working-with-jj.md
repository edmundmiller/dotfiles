---
description: Keep shared Jujutsu working copies stable
condition: "\\bjj\\b"
scope: "tool:bash"
---

## Working with jj (Jujutsu)

These workspaces are often a **single shared working copy** used across multiple
agent sessions and live dev servers. The working copy `@` is shared state — treat
it that way. My recurring failure has been _appearing_ to lose changes; the work
is almost never actually lost (`jj` snapshots everything; `jj op log` + `jj undo` /
`jj op restore` is fully reversible), but bad working-copy discipline makes files
vanish from the checkout and fragments work. Hold to these rules everywhere:

- **Never `jj edit <bookmark>` just to inspect.** `jj edit` rewrites the on-disk
  working copy to that commit, yanking files out from under other sessions and any
  dev server rendering `@`. Only `jj edit` to _deliberately_ switch which branch
  this workspace edits — and say so / confirm first, since it changes what the
  user sees.
- **Read other branches without moving `@`:** `jj diff -r <bm>`,
  `jj file show -r <bm> <path>`, `jj log -r <bm>`.
- **Stay on one bookmark per workspace.** Don't hop `@` around.
- **Reuse the existing bookmark/PR.** Don't spin up new branches/PRs when work
  feels tangled — edit in place. Only create a new one if explicitly asked.
- **Edit in place:** change files → `jj` auto-snapshots into `@` →
  `jj describe`/`jj squash` to shape the commit → `jj bookmark set <bm> -r @` →
  `jj git push`.
- **Verify before acting:** `pwd` + `jj log -r @` at the top of any change, so the
  folder and branch are confirmed right.
- **Recover, don't rebuild:** if something looks gone, it's `jj op log` →
  `jj undo` / `jj op restore`, never a rebuild from scratch.
