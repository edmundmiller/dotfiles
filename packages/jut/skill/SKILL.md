---
name: jut
version: 0.1.0
description: "Jujutsu version control through jut, a human and agentic framework around jj. Use for: check status, view changes, commit work, create branches, push, pull, create PRs, squash commits, reword messages, absorb changes, undo operations, view history. Complements jj — use jut for opinionated workflows, drop into raw jj for everything else."
author: Edmund Miller
---

# jut — Jujutsu CLI Skill

Use `jut` as the primary interface for jj version control. jut is a thin opinionated layer — not a replacement. Drop into raw `jj` for anything jut doesn't cover.

## Non-Negotiable Rules

1. Start every task with `jut status --json` to get workspace state, stack structure, and change IDs.
2. For all mutations, always use `--json --status-after`.
3. Use short IDs from `jut status --json` output (`short_id` field) to reference revisions.
4. After a successful `--status-after`, do not run redundant `jut status`.
5. Use raw `jj` for interactive commands (split, resolve, diffedit, edit, rebase) — jut intentionally does not wrap these.
6. Never fabricate change IDs. Always read them from `jut status`, `jut log`, or `jut show` output first.
7. jj has no staging area. The working copy IS the stage. Don't look for `add`/`stage` commands.

## Core Flow

```bash
# 1. Understand workspace state
jut status --json

# 2. Perform mutations with structured feedback
jut <command> --json --status-after

# 3. For complex operations, drop into jj
jj split -r <rev>
jj rebase -r <rev> -d <dest>
```

## Command Reference

### Inspection

```bash
jut status                       # Workspace state: stacks, bookmarks, files
jut status -f                    # Include file-level details
jut status -v                    # Verbose: author + timestamps
jut log                          # Revision history (default: 20)
jut log -n 50                    # More revisions
jut log --all                    # All revisions
jut diff                         # Working copy diff
jut diff <rev>                   # Diff of specific revision
jut show <rev>                   # Revision details
jut show <rev> -v                # With inline diff
```

### Committing

```bash
jut commit -m "message"          # Describe @ + create new empty change
jut commit                       # Opens editor for message
```

jj's model: the working copy is always a commit. `jut commit` describes it and creates a new empty change on top — like `jj commit`.

### Branching

```bash
jut branch <name>                # Create branch from trunk + new change
jut branch <name> --stack        # Stack: branch from @ (dependent work)
jut branch <name> --from <rev>   # Branch from specific revision
jut branch -l                    # List branches (same as status)
jut branch -d <name>             # Delete branch
jut branch --rename <old> <new>  # Rename branch
```

### The Rub Primitive

`rub` is the universal "combine two things" verb (from GitButler). It replaces several jj commands based on what SOURCE and TARGET are:

```bash
jut rub <source> <target>        # Or: jut <source> <target>
```

| SOURCE → TARGET     | Action                 | jj equivalent                         |
| ------------------- | ---------------------- | ------------------------------------- |
| file → revision     | Amend file into commit | `jj squash --into <rev> <file>`       |
| file → `zz`         | Discard file changes   | `jj restore <file>`                   |
| revision → revision | Squash into target     | `jj squash --from <src> --into <tgt>` |
| revision → `zz`     | Abandon revision       | `jj abandon <rev>`                    |

`zz` is the discard target — the trash can.

### Squash & Reword

```bash
jut squash                       # Squash @ into parent
jut squash <rev>                 # Squash <rev> into its parent
jut squash <from> <into>         # Squash <from> into <into>
jut squash <from> <into> -m "x"  # With new message
jut reword <rev> -m "new msg"    # Edit commit message
jut reword <rev>                 # Opens editor
```

### Discard

```bash
jut discard <file>               # Restore file (discard changes)
jut discard <rev>                # Abandon revision
```

Auto-detects whether target is a file path or revision ID.

### Absorb

```bash
jut absorb                       # Auto-amend changes into the right commits
jut absorb --dry-run             # Show plan without applying
```

### Push, Pull & PR

```bash
jut push                         # Push all bookmarks
jut push <bookmark>              # Push specific bookmark
jut pull                         # Fetch + rebase onto trunk
jut pull --clean                 # Also delete merged bookmarks
jut pull --no-rebase             # Fetch only
jut pull --dry-run               # Show plan
jut pr                           # Create PR for current bookmark (via gh)
jut pr <bookmark>                # Create PR for specific bookmark
jut pr -m "title\nbody"         # With message
```

### History

```bash
jut undo                         # Undo last operation
jut oplog                        # View operation history
jut oplog -n 20                  # More operations
jut oplog restore <op-id>        # Restore to previous state
```

## JSON Output Shapes

All commands support `--json` (or `-j`). Key shapes:

### `jut status --json`

```json
{
  "trunk": { "change_id": "...", "short_id": "...", "bookmarks": ["main"], ... },
  "stacks": [
    {
      "bookmarks": ["feature-x"],
      "revisions": [
        {
          "change_id": "abc123...",
          "commit_id": "def456...",
          "short_id": "abc",
          "description": "add feature x",
          "bookmarks": ["feature-x"],
          "is_empty": false,
          "is_working_copy": true,
          "is_conflicted": false,
          "is_immutable": false,
          "parent_change_ids": ["..."],
          "author": "user@example.com",
          "timestamp": "2026-02-10 13:00",
          "files": [{ "status": "M", "path": "src/main.rs" }]
        }
      ]
    }
  ],
  "working_copy": null,
  "uncommitted_files": [],
  "shared_base": []
}
```

### `jut log --json`

```json
{
  "revisions": [
    { "change_id": "...", "short_id": "...", "description": "...", "bookmarks": [...], ... }
  ]
}
```

### `jut pull --json`

```json
{
  "fetched": true,
  "rebased": true,
  "merged_bookmarks": ["old-feature"],
  "cleaned_bookmarks": [],
  "conflicts": []
}
```

### `jut pr --json`

```json
{
  "created": true,
  "bookmark": "feature-x",
  "pr_url": "https://github.com/user/repo/pull/42"
}
```

## Task Recipes

### Start new feature work

```bash
jut pull --clean --json --status-after
jut branch my-feature --json --status-after
# ... make changes ...
jut commit -m "implement feature" --json --status-after
```

### Start stacked work (depends on current branch)

```bash
jut branch part-2 --stack --json --status-after
# ... make changes ...
jut commit -m "part 2" --json --status-after
```

### Ship a feature

```bash
jut push --json --status-after
jut pr --json
```

### Amend a file into an older commit

```bash
jut status --json                          # Find the file and target revision short_id
jut rub <file> <rev> --json --status-after  # Amend file into that commit
```

### Discard all changes to a file

```bash
jut rub <file> zz --json --status-after
# or equivalently:
jut discard <file> --json --status-after
```

### Abandon a revision

```bash
jut rub <rev> zz --json --status-after
# or equivalently:
jut discard <rev> --json --status-after
```

### Clean up after pull (delete merged bookmarks)

```bash
jut pull --clean --json --status-after
```

### Undo a mistake

```bash
jut undo --json --status-after
# If you need to go further back:
jut oplog --json                           # Find the operation
jut oplog restore <op-id> --json --status-after
```

### Split a commit (drop to jj)

```bash
jut status --json    # Get the revision ID
jj split -r <rev>    # Interactive split in jj
jut status --json    # Refresh state
```

### Rebase work (drop to jj)

```bash
jj rebase -r <rev> -d <dest>
jut status --json    # Refresh state
```

### Resolve conflicts (drop to jj)

```bash
jut status --json          # See conflicted revisions (is_conflicted: true)
jj resolve -r <rev>        # Interactive merge tool
jut status --json          # Verify resolution
```

## When to Use jj Directly

jut intentionally skips these — use raw `jj`:

| Command                  | Why                                              |
| ------------------------ | ------------------------------------------------ |
| `jj split`               | Interactive editor — can't improve on it         |
| `jj edit <rev>`          | Trivial one-liner                                |
| `jj rebase`              | Complex revset args — wrapping loses flexibility |
| `jj resolve`             | Interactive merge tool                           |
| `jj diffedit`            | Interactive editor                               |
| `jj next` / `jj prev`    | Trivial navigation                               |
| `jj new`                 | Covered by `jut commit` and `jut branch`         |
| `jj describe`            | Covered by `jut reword`                          |
| `jj abandon`             | Covered by `jut discard`                         |
| `jj bookmark` (advanced) | `jut branch` covers common cases                 |
| `jj config`              | Config management, not a repo operation          |

Read-only `jj` commands are always fine alongside jut (`jj log`, `jj evolog`, `jj show`, `jj diff`).

## Notes

- jj has no staging area. Every change is immediately part of the working copy commit.
- The working copy (`@`) is always a revision. `jut commit` describes it and creates a new one.
- Change IDs (reverse hex) are stable across rebases. Commit IDs change. Always prefer change IDs.
- `short_id` from JSON output is the shortest unique prefix — use these for brevity.
- `rub` is positional: `jut <source> <target>` works without the `rub` subcommand.
- `zz` is the universal discard target for `rub`.
- `--status-after` returns the full workspace state after mutation — eliminates a round-trip.
- jut and jj coexist freely. No setup/teardown. Switch between them at will.
