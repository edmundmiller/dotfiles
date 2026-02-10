# jut Command Reference

Comprehensive reference for all `jut` commands.

## Contents

- [Inspection](#inspection) — `status`, `log`, `diff`, `show`
- [Committing](#committing) — `commit`
- [Branching](#branching) — `branch`
- [Editing History](#editing-history) — `rub`, `squash`, `reword`, `discard`, `absorb`
- [Remote Operations](#remote-operations) — `push`, `pull`, `pr`
- [History & Undo](#history--undo) — `undo`, `oplog`
- [Skill Management](#skill-management) — `skill`
- [Global Options](#global-options)

## Inspection

### `jut status`

Workspace state: stacks, bookmarks, working copy, files.

```bash
jut status                    # Human-readable stack visualization
jut status -f                 # Include file-level details per revision
jut status -v                 # Verbose: author + timestamps
jut status --json             # Structured WorkspaceState JSON
```

Shows:

- Stacks branching from trunk, rendered with tree-drawing characters
- Working copy revision with `@` marker
- Bookmarks on each revision
- Empty (∅), conflicted, and immutable markers
- File changes per revision (with `-f` or for working copy)

### `jut log`

Revision history.

```bash
jut log                       # Last 20 revisions (human: jj log passthrough)
jut log -n 50                 # Last 50 revisions
jut log --all                 # All revisions
jut log --json                # Structured: { revisions: [RevisionInfo...] }
```

Human mode passes through to `jj log` for native formatting. JSON mode returns structured `RevisionInfo` objects via jj templates.

### `jut diff`

Show diff of changes.

```bash
jut diff                      # Working copy diff
jut diff <rev>                # Diff of specific revision
jut diff --json               # Structured: { files_changed, stats, raw }
```

### `jut show`

Revision details.

```bash
jut show <rev>                # Show revision info
jut show <rev> -v             # Include inline diff
jut show --json               # Structured revision output
```

## Committing

### `jut commit`

Describe the working copy and create a new empty change on top.

```bash
jut commit -m "message"       # Non-interactive commit
jut commit                    # Opens editor (via jj commit)
jut commit --json             # Returns { committed, message, new_change_id }
```

In jj's model, the working copy is always a revision. `jut commit` describes it (`jj describe`) then creates a new empty change (`jj new`). This is equivalent to `jj commit`.

**JSON mode requires `-m`** — no editor interaction in structured output.

## Branching

### `jut branch`

Create and manage bookmarks (jj's term for branches).

```bash
jut branch <name>             # Create branch from trunk + new change
jut branch <name> --stack     # Stack: branch from @ (dependent work)
jut branch <name> --from <rev>  # Branch from specific revision
jut branch -l                 # List branches (renders status view)
jut branch -d <name>          # Delete branch
jut branch --rename <old> <new>  # Rename branch (set new + delete old)
```

**Create** (`jut branch <name>`):

1. `jj new -r trunk()` (or `@` with `--stack`, or custom `--from`)
2. `jj bookmark set <name>` on the new revision
3. Returns `{ created, bookmark, change_id, base, stacked }`

**Stack** creates dependent work — the new branch starts from the current working copy, not trunk.

**List** (`jut branch -l`) reuses the status rendering, showing all stacks with their bookmarks.

## Editing History

### `jut rub <source> <target>`

The universal "combine two things" primitive, inspired by GitButler.

```bash
jut rub <source> <target>     # Explicit rub subcommand
jut <source> <target>         # Implicit: positional args without subcommand
```

**Operations matrix:**

| SOURCE → TARGET     | Action                 | jj equivalent                         |
| ------------------- | ---------------------- | ------------------------------------- |
| file → revision     | Amend file into commit | `jj squash --into <rev> <file>`       |
| file → `zz`         | Discard file changes   | `jj restore <file>`                   |
| revision → revision | Squash into target     | `jj squash --from <src> --into <tgt>` |
| revision → `zz`     | Abandon revision       | `jj abandon <rev>`                    |

**Detection:** Source is treated as a file if the path exists on disk. `zz` is the universal discard target.

**JSON output:** `{ action, source, target, output }` where action is one of `restore`, `amend`, `abandon`, `squash`.

### `jut squash`

Squash revisions together.

```bash
jut squash                    # Squash @ into parent
jut squash <rev>              # Squash <rev> into its parent
jut squash <from> <into>      # Squash <from> into <into>
jut squash <from> <into> -m "msg"  # With new message
```

Wraps `jj squash` with positional `--from`/`--into` args.

### `jut reword <target>`

Edit commit message (wraps `jj describe -r`).

```bash
jut reword <rev> -m "new msg" # Non-interactive
jut reword <rev>              # Opens editor
```

### `jut discard <target>`

Unified discard — auto-detects file vs revision.

```bash
jut discard <file>            # Restore file (jj restore <file>)
jut discard <rev>             # Abandon revision (jj abandon <rev>)
```

Detection: if the path exists on disk, it's a file restore. Otherwise it's an abandon.

### `jut absorb`

Auto-amend changes into the right commits.

```bash
jut absorb                    # Apply absorb
jut absorb --dry-run          # Show plan without applying
```

Wraps `jj absorb`.

## Remote Operations

### `jut push`

Push bookmarks to remote.

```bash
jut push                      # Push all bookmarks (jj git push)
jut push <bookmark>           # Push specific bookmark
jut push --json               # Returns { pushed, bookmark, output }
```

### `jut pull`

Fetch from remote + rebase onto trunk + detect merged bookmarks.

```bash
jut pull                      # Fetch + rebase
jut pull --clean              # Also delete bookmarks merged into trunk
jut pull --no-rebase          # Fetch only, skip rebase
jut pull --dry-run            # Show execution plan
```

**Three-phase operation:**

1. `jj git fetch`
2. `jj rebase -b "all:roots(trunk()..mutable())" -d trunk()` (unless `--no-rebase`)
3. Detect bookmarks whose commits are ancestors of trunk (merged)

With `--clean`, merged bookmarks are auto-deleted (excluding `main`, `master`, and remote-tracking bookmarks).

**JSON output:**

```json
{
  "fetched": true,
  "rebased": true,
  "merged_bookmarks": ["old-feature"],
  "cleaned_bookmarks": ["old-feature"],
  "conflicts": []
}
```

### `jut pr`

Create a PR via `gh` CLI.

```bash
jut pr                        # Auto-detect bookmark on @, push + create PR
jut pr <bookmark>             # Create PR for specific bookmark
jut pr -m "title\nbody"      # With message (first line = title)
```

**Workflow:**

1. Resolve bookmark (from arg or current revision)
2. `jj git push -b <bookmark>`
3. `gh pr create --head <bookmark>` (with `--fill` or `--title`/`--body`)

**JSON output:** `{ created, bookmark, pr_url }`

**Requires:** `gh` CLI installed and authenticated.

## History & Undo

### `jut undo`

Undo the last jj operation.

```bash
jut undo                      # Wraps jj undo
jut undo --json               # Returns { undone, output }
```

### `jut oplog`

View operation history.

```bash
jut oplog                     # Last 10 operations (excludes snapshots)
jut oplog -n 20               # More operations
jut oplog --all               # Include snapshot operations
jut oplog restore <op-id>     # Restore workspace to a previous operation
```

Wraps `jj operation log` with snapshot filtering by default.

## Skill Management

### `jut skill`

Manage jut AI skill files for coding agents.

```bash
jut skill                     # Print skill to stdout (same as show)
jut skill show                # Print SKILL.md content
jut skill install             # Install to .agents/skills/jut/ (project-local)
jut skill install --global    # Install to ~/.pi/agent/skills/jut/ + ~/.claude/skills/jut/
jut skill install --target <dir>  # Custom target directory
jut skill check               # Check if installed skill matches CLI version
jut skill check --update      # Auto-update outdated installations
```

## Global Options

Available on all commands:

- `--json` / `-j` — Structured JSON output for agent consumption
- `--format human|json` / `-f` — Output format (default: human, env: `JUT_OUTPUT_FORMAT`)
- `--status-after` — After mutation, also output workspace status
- `-C <PATH>` — Run as if started in PATH instead of cwd
- `-h` / `--help` — Show help
- `-V` / `--version` — Show version

## Dropping to jj

jut intentionally does not wrap everything. Use raw `jj` for:

- `jj split` — interactive commit splitting
- `jj edit <rev>` — switch working copy to older revision
- `jj rebase` — complex history rewriting with revsets
- `jj resolve` — interactive conflict resolution with merge tool
- `jj diffedit` — interactive diff editing
- `jj next` / `jj prev` — working copy navigation
- `jj new` (advanced) — covered by `jut commit` and `jut branch` for common cases
- `jj bookmark` (advanced) — `jut branch` covers common cases

Read-only `jj` commands always work alongside jut (`jj log`, `jj evolog`, `jj show`, etc.).
