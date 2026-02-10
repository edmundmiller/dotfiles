# jut Concepts

Core concepts for understanding jut and jj's model.

## jj's Working Copy Model

Unlike git, jj has **no staging area**. The working copy is always a commit.

- Every file change is immediately part of the working copy revision (`@`)
- `jut commit` = describe `@` + create new empty change on top
- There's no `add`/`stage` step — changes are always tracked
- `jj` auto-snapshots the working copy before every operation

This means you never lose work — every state is recorded.

## Change IDs vs Commit IDs

jj has two kinds of identifiers:

| Type          | Format                         | Stability             | Use                 |
| ------------- | ------------------------------ | --------------------- | ------------------- |
| **Change ID** | Reverse hex (e.g., `kxryzmvp`) | Stable across rebases | Prefer this         |
| **Commit ID** | Hex (e.g., `a1b2c3d4`)         | Changes on rebase     | Avoid when possible |

**Always use change IDs** (the `change_id` / `short_id` fields in JSON output). They survive rebases and history editing. Commit IDs change whenever the commit content changes.

`short_id` in jut's JSON output is the shortest unique prefix of the change ID — use these for brevity in commands.

## The Rub Primitive

`rub` is jut's universal "combine two things" verb, borrowed from GitButler.

### Operations Matrix

```
SOURCE ↓ / TARGET →  │ zz (discard)  │ Revision
─────────────────────┼───────────────┼──────────────────
File                 │ Restore       │ Squash/amend into
Revision             │ Abandon       │ Squash together
```

`zz` is a special target meaning "discard" — the trash can.

### Detection Logic

- **File**: source path exists on disk (absolute or relative to repo root)
- **Revision**: anything else (change ID, short ID, bookmark name)
- **Discard**: target is literally `zz`

### Why One Primitive?

One powerful operation is easier to learn than many specialized commands. Once you understand `rub`, you understand the editing model:

- `jut rub src/main.rs abc` → amend file into revision `abc`
- `jut rub src/main.rs zz` → discard changes to file
- `jut rub abc def` → squash revision `abc` into `def`
- `jut rub abc zz` → abandon revision `abc`

And the implicit form works too: `jut src/main.rs abc` (no `rub` keyword needed).

## Stacks

jut visualizes commits as **stacks** — linear chains from trunk to bookmark tips. This mirrors GitButler's workspace model.

### Stack Detection

1. Find all local bookmarks
2. Walk parents from each bookmark back to trunk
3. Group into linear chains
4. Identify shared base revisions (fork points between stacks)

### Stack Visualization

```
╭┄abc [feature-x]          ← stack header (short_id + bookmark)
┊● def Add feature logic    ← commit (● = has changes)
┊● ghi Add tests            ← another commit
┊○ jkl (no description) @   ← working copy (@ marker)
├╯
┊
┴ mno (trunk) [main]        ← common base
```

Markers:

- `●` — commit with changes
- `○` — empty commit (dimmed)
- `●` (cyan) — working copy
- `●` (red) — conflicted
- `@` — working copy indicator
- `∅` — empty (non-working-copy)

### Parallel Stacks

Multiple bookmarks branching from trunk appear as parallel stacks, each rendered independently. Shared base revisions (fork points) are shown between stacks.

## Bookmarks (jj's Branches)

jj calls branches "bookmarks." They're labels on commits, not ref pointers like git branches.

Key differences from git:

- Bookmarks are local by default
- Remote tracking is explicit (`bookmark@origin`)
- Bookmarks don't "advance" — they stay where you set them
- Use `jj bookmark set` to update (or `jut branch` for common cases)

`jut branch` manages bookmarks with opinion:

- `jut branch <name>` = `jj new -r trunk()` + `jj bookmark set <name>`
- `jut branch <name> --stack` = `jj new -r @` + `jj bookmark set <name>`

## Trunk

"Trunk" is jj's concept for the main development line. It's resolved by the `trunk()` revset function, typically pointing at `main` or `master`.

- `jut pull` rebases all mutable work onto trunk
- `jut branch` creates branches from trunk by default
- `jut status` shows trunk as the common base of all stacks

## Operation Log

Every jj command records an operation in the operation log (oplog). This provides:

- Full history of all workspace mutations
- Point-in-time restore (`jut oplog restore <op-id>`)
- Single-step undo (`jut undo`)

Think of it as "git reflog" but for ALL operations, not just ref movements. Made a mistake? `jut undo`. Want to go further back? Browse `jut oplog` and restore.

## JSON Mode

Every jut command supports `--json` (or `-j`) for structured output. This is the primary interface for AI agents.

### Design Principles

1. **Same data, different format** — JSON and human modes show the same information
2. **Stable schema** — JSON shapes don't change between minor versions
3. **Self-contained** — each response includes all IDs needed for follow-up commands
4. **`--status-after`** — mutation commands can return workspace state in the same response, eliminating a round-trip

### Agent Workflow

```
jut status --json           → understand workspace state
jut <mutation> --json --status-after  → act + get updated state
                             → no redundant status call needed
```

## Coexistence with jj

jut is a thin layer, not a walled garden. Key design principles:

1. **No setup/teardown** — jut works in any jj repo, immediately
2. **Same repository** — jut reads/writes the same jj repo state
3. **CLI wrapping** — jut calls `jj` commands internally, ensuring identical semantics
4. **Drop in/out freely** — use `jj split`, then `jut status`, then `jj rebase`, then `jut push`
5. **Read-only jj always safe** — `jj log`, `jj show`, `jj diff`, `jj evolog` work alongside jut

This is the opposite of GitButler's model, where `but setup`/`but teardown` creates a boundary between `but` and `git`.
