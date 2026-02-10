# jut - JJ User Tools (GitButler-inspired CLI for jj)

A GitButler-inspired CLI wrapper around [Jujutsu (jj)](https://jj-vcs.dev) that provides:

- **Short CLI IDs** for revisions (4+ char, collision-extending)
- **`--json` output** with `--status-after` for AI agent workflows
- **`rub` primitive** — universal "combine two things" operation
- **PR creation via `gh`** — no GitHub app required
- **Consistent UX** matching `but` command patterns

## Why?

GitButler (`but`) has excellent UX for AI agents, but requires a GitHub app for PRs.
jj has excellent VCS primitives but lacks the agent-friendly wrapper.
`jut` bridges the gap.

## Architecture

- **Rust binary** using `clap` for CLI
- **jj CLI** for operations (stable interface)
- **jj-lib** available for future direct integration
- **gh CLI** for PR creation (no GitHub app dependency)

## Command Reference

| jut command           | jj equivalent                  | Description                       |
| --------------------- | ------------------------------ | --------------------------------- |
| `jut status`          | `jj status` + `jj log`         | Workspace overview with short IDs |
| `jut diff`            | `jj diff`                      | Show diff                         |
| `jut show <rev>`      | `jj show`                      | Revision details                  |
| `jut commit -m "msg"` | `jj describe` + `jj new`       | Commit and start new change       |
| `jut rub <src> <tgt>` | varies                         | Universal combine primitive       |
| `jut squash`          | `jj squash`                    | Squash revisions                  |
| `jut reword <rev>`    | `jj describe`                  | Edit commit message               |
| `jut push`            | `jj git push`                  | Push bookmarks                    |
| `jut pull`            | `jj git fetch`                 | Fetch upstream                    |
| `jut pr`              | `jj git push` + `gh pr create` | Create PR (no app needed)         |
| `jut discard`         | `jj restore` / `jj abandon`    | Discard changes                   |
| `jut undo`            | `jj undo`                      | Undo last operation               |
| `jut absorb`          | `jj absorb`                    | Auto-amend into right commits     |
| `jut log`             | `jj log`                       | Show revision log                 |

## The `rub` Primitive

Inspired by GitButler's universal combine command:

```text
SOURCE / TARGET  │ zz (discard)     │ Revision              │ Bookmark
─────────────────┼──────────────────┼───────────────────────┼─────────────
File             │ jj restore file  │ jj squash --into rev  │ -
Revision         │ jj abandon rev   │ jj squash rev into    │ jj rebase
```

```bash
jut rub README.md abc1234    # Amend file into revision
jut rub abc1234 def5678      # Squash revisions together
jut rub abc1234 zz           # Abandon revision
jut rub hello.txt zz         # Restore file (discard changes)
jut abc1234 def5678          # Default: rub (no subcommand needed)
```

## Agent-Friendly Features

```bash
# JSON output
jut status --json
jut commit -m "fix" --json

# Status after mutations
jut commit -m "fix" --json --status-after
# Returns: {"committed": ..., "message": ...} then {"change_id": ..., "files_changed": ...}

# Short IDs throughout
jut status
# @ okpt (okptlzllmqkz)
#   2 file(s) changed
```

## Installation

```nix
# In host config
environment.systemPackages = [ pkgs.jut ];
```

Or build directly:

```bash
cd packages/jut
cargo build --release
```
