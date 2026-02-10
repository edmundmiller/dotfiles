# jut: Implement branch, pull enhancement, and oplog

## What is jut?

`jut` is a Rust CLI wrapper around [jj (Jujutsu)](https://jj-vcs.dev) that mirrors GitButler's (`but`) agent-friendly UX. It lives at `packages/jut/` in the dotfiles repo.

## Your Mission

Implement three features to complete the core GitButler CLI workflow. Work in priority order — `branch` unblocks `pull`.

### 1. `jut branch` (P1, dotfiles-dg9u — do first)

Create/manage branches. This is the biggest gap — without it users can't do the basic "create a branch, do work, create another branch" flow.

**Subcommands:**

- `jut branch <name>` — create parallel branch from trunk, set bookmark, move working copy there. Maps to: `jj new -r "trunk()" && jj bookmark set <name>`
- `jut branch --stack/-s <name>` — create stacked branch from current `@` (dependent work). Maps to: `jj new && jj bookmark set <name>`
- `jut branch --list/-l` — list branches with stack relationships. Reuse `workspace_state()` from `stack.rs`
- `jut branch --delete/-d <name>` — delete bookmark. Maps to: `jj bookmark delete <name>`
- `jut branch --rename <old> <new>` — rename bookmark (jj 0.37: `jj bookmark set <new> -r <old-target> && jj bookmark delete <old>`)
- `--from <rev>` — override base revision for create/stack

**JSON output:** `{"created": true, "bookmark": "name", "change_id": "...", "base": "trunk"}`

### 2. `jut pull` enhancement (P1, dotfiles-wkch.13 — depends on branch)

Current `pull.rs` only does `jj git fetch`. Enhance to handle "update your base":

1. `jj git fetch`
2. `jj rebase -b "all:roots(trunk()..mutable())" -d trunk()` — rebase all stacks
3. Detect merged bookmarks: `jj log -r "bookmarks() & ::trunk()"`
4. Report merged bookmarks; with `--clean/-c` auto-delete them
5. `--no-rebase` flag preserves current fetch-only behavior
6. `--dry-run` shows plan without executing

**JSON output:** `{"fetched": true, "rebased": true, "merged_bookmarks": [...], "cleaned_bookmarks": [...], "conflicts": [...]}`

Handle edge cases: trunk unchanged (no-op), nothing fetched, rebase conflicts (report but don't auto-clean).

### 3. `jut oplog` (P2, dotfiles-wkch.14 — independent)

Operations history for "go back in time":

- `jut oplog` — list recent ops (default 10) with short IDs, timestamps, descriptions
- `jut oplog --limit N` — control count
- `jut oplog --all` — include snapshot operations (filtered by default)
- `jut oplog restore <op-id>` — restore to previous state. Maps to: `jj operation restore <op-id>`

Parse `jj operation log` with custom template using the same `\x1e`/`\x1f` separator pattern as `stack.rs`. Use short collision-extending IDs from `id/mod.rs`.

**JSON output:** `{"operations": [{"id": "...", "short_id": "...", "description": "...", "timestamp": "...", "snapshot": false}]}`

## Architecture — What You Need to Know

**Key files to read first:**

- `src/args.rs` — CLI arg definitions (add new subcommands here)
- `src/main.rs` — command dispatch (wire new commands here)
- `src/command/mod.rs` — module declarations
- `src/stack.rs` — DAG parsing with `\x1e`/`\x1f` template separators, `workspace_state()`. **Critical pattern to reuse.** Note the `--config=ui.log-word-wrap=false` trick to prevent jj wrapping.
- `src/repo.rs` — `Repo` struct with `jj_cmd()` helper, `bookmarks()`, `current_change_id()`
- `src/output.rs` — `OutputChannel` with `human()`, `write_json()`, `is_json()`
- `src/id/mod.rs` — `ShortIdMap` for collision-extending short IDs
- `src/command/pull.rs` — current fetch-only implementation to enhance
- `src/command/status.rs` — tree-drawing rendering (reference for branch --list)

**Patterns to follow:**

- Every command takes `(args: &Args, out: &mut OutputChannel) -> Result<()>`
- Use `repo.jj_cmd(&[...])` for all jj CLI calls
- Human output via `out.human()`, JSON via `out.write_json()`
- Check `args.status_after` at the end of mutation commands
- Tests go in `tests/integration.rs` — write spec tests + regression tests for each feature

**jj version:** 0.37.0. Note: uses `-n` not `--limit`, `bookmark` not `branch`.

## Testing

```bash
cargo test                    # run all tests
cargo test branch             # run branch-related tests
cargo build && cd /tmp/jj-test && /path/to/jut status  # manual testing
```

Create test jj repos in integration tests using `TempDir` + `Command::new("jj")` — see existing tests for the pattern. Use `-n 1` (not `--limit 1`) for jj 0.37.

## Beads Tracking

Update beads as you work:

```bash
bd update dotfiles-dg9u --status in_progress
bd update dotfiles-dg9u --notes "COMPLETED: ... IN PROGRESS: ..."
bd close dotfiles-dg9u --reason "Implemented branch subcommand with create/stack/list/delete/rename"
```

Close issues in the git commit that implements them: `Closes dotfiles-dg9u`.

## Definition of Done

- [ ] `jut branch` creates parallel and stacked branches
- [ ] `jut branch --list` shows stack relationships
- [ ] `jut pull` fetches + rebases + detects merged bookmarks
- [ ] `jut pull --clean` removes merged bookmarks
- [ ] `jut oplog` lists operations with short IDs
- [ ] `jut oplog restore` restores previous state
- [ ] All commands support `--json` output
- [ ] All mutation commands support `--status-after`
- [ ] Integration tests for each feature
- [ ] `cargo test` passes, `cargo build` clean (no warnings)
- [ ] Beads issues closed with commit references
