# pi-context-repo

Git-backed persistent memory filesystem for [pi](https://github.com/mariozechner/pi-coding-agent) agents, inspired by [Letta Code's Context Repositories](https://www.letta.com/blog/context-repositories).

## Install

```bash
pi install /path/to/pi-context-repo
# or after publishing:
pi install npm:pi-context-repo
```

## How it works

Memory is stored as markdown files with YAML frontmatter in `.pi/memory/` (a separate git repo inside your project).

- **`system/`** files are pinned to the system prompt every turn
- **Other files** appear in the tree — the agent reads them on demand (progressive disclosure)
- **Git versioning** tracks all memory changes with informative commits
- **Frontmatter** enforces `description`, `limit`, and optional `read_only` per file

- **`$MEMORY_DIR`** env var injected into shell so bash commands can reference memory

### Scaffolded structure (auto-created on first run)

```
.pi/memory/
├── system/
│   ├── persona.md  — Agent identity and behavior
│   ├── user.md     — User preferences and context
│   ├── project.md  — Codebase knowledge and conventions
│   └── style.md    — Coding preferences
└── reference/
    └── README.md   — How to use reference/
```

## Tools

| Tool            | Description                                                    |
| --------------- | -------------------------------------------------------------- |
| `memory_list`   | List memory markdown files (optionally scoped to a directory)  |
| `memory_read`   | Read one memory file by relative path                          |
| `memory_write`  | Write/update a memory file (auto-stages, respects `read_only`) |
| `memory_delete` | Delete a memory file and stage the removal                     |
| `memory_commit` | Commit staged changes with a descriptive message               |
| `memory_search` | Search memory files by content (`git grep`)                    |
| `memory_log`    | Show recent commit history                                     |
| `memory_recall` | Search prior pi session history for matching conversation text |
| `memory_backup` | Create a timestamped backup snapshot                           |

## Commands

| Command            | Description                                                                    |
| ------------------ | ------------------------------------------------------------------------------ |
| `/memory`          | Show tree, status, recent history, reminder mode, and latest reflection bundle |
| `/sleeptime`       | Show or configure memory reminder triggers                                     |
| `/reflect`         | Prepare a Letta-style reflection bundle and try background launch              |
| `/init`            | Initialize or re-analyze memory                                                |
| `/remember [text]` | Explicitly save something to memory                                            |
| `/memory-diff`     | Show uncommitted changes                                                       |
| `/memory-backup`   | Create a timestamped backup                                                    |
| `/memory-backups`  | List available backups                                                         |
| `/memory-restore`  | Restore from a backup                                                          |
| `/memory-export`   | Export memory to a directory                                                   |
| `/memory-import`   | Import memory from another directory                                           |

## Bundled skills

- `initializing-memory` — deep `/init` workflow and first-run memory population
- `defragmenting-memory` — split/clean memory blocks into focused files
- `searching-memory` — fast browse/search/read/sync workflows for daily usage

## Reminder behavior

Inspired by Letta's memory reminder model, pi-context-repo now supports configurable memory check triggers:

- **`step-count`** — remind every _N_ turns (`15` by default)
- **`compaction-event`** — remind after an auto-compaction event
- **`off`** — disable automatic reminders; use `/remember` manually

Use `/sleeptime status`, `/sleeptime step-count 10`, `/sleeptime compaction-event`, or `/sleeptime off` to manage the mode.

Memory reminders are injected as **system reminders**, not user messages. They are cues to silently consolidate memory when useful — the agent should apply the information naturally rather than narrating "I remembered..." unless the user explicitly invoked `/remember`.

When a reminder fires, pi-context-repo now also prepares a **reflection bundle** under `.pi/reflection-runtime/` containing:

- a bounded transcript snapshot of the current session branch
- a reflection prompt file with memory paths and current pinned-memory context
- metadata describing the trigger source and bundle paths

The extension then emits an optional event-bus launch request on `pi-context-repo:reflection-launch`. A separate extension/runtime component can accept that request and run a real background reflection worker. If nothing accepts it, pi-context-repo falls back to the normal in-band `MEMORY CHECK` system reminder.

This means the Letta-style reflection system is now **partially ported**: transcript prep, launch contract, fallback handoff, and `/reflect` exist here; a true autonomous background worker still requires another extension/runtime component to consume the launch event.

## UI

- **Status widget** shows uncommitted/unpushed counts in pi footer
- **Sync reminder** appears in the system prompt when changes need committing/pushing
- **Memory check reminder** can fire on step count or compaction events
- **Reflection bundles** capture transcript/prompt artifacts for manual or external background reflection
- **Bounded tree rendering** avoids prompt blowups on very large memory repos
- **Drift detection** warns about legacy/orphan memory fragments in system prompt

## Design

Adapted from Letta Code's [memoryGit.ts](https://github.com/letta-ai/letta-code/blob/main/src/agent/memoryGit.ts), [memoryFilesystem.ts](https://github.com/letta-ai/letta-code/blob/main/src/agent/memoryFilesystem.ts), [memoryReminder.ts](https://github.com/letta-ai/letta-code/blob/main/src/cli/helpers/memoryReminder.ts), and Letta's reflection transcript / background reflection flow (`cli/helpers/reflectionTranscript.ts`, `agent/subagents/builtin/reflection.md`, `tests/cli/reflection-auto-launch-wiring.test.ts`) along with the broader [Context Repositories](https://docs.letta.com/letta-code/memory) concept:

- Files as memory units with metadata frontmatter
- `system/` subdir always loaded (like Letta's pinned memory blocks)
- File tree always visible for on-demand loading
- Git for versioning, history, and eventual multi-agent sync
- Natural memory application — no "I remember that..." narration
- Git worktree helpers for isolated background edits (reflection, migration)
- Reflection bundle preparation + optional event-bus handoff for external background workers
- System prompt drift detection and stripping
- `$MEMORY_DIR` / `$PI_MEMORY_DIR` env vars for shell access

## pi-memory-md parity decisions

See [`docs/pi-memory-md-parity.md`](./docs/pi-memory-md-parity.md) for accepted vs rejected UX parity items and rationale.

## Competitive landscape

Compared against [letta-code](https://github.com/letta-ai/letta-code), [pi-memory](https://www.npmjs.com/package/pi-memory) (jayzeng), and [pi-memory-md](https://www.npmjs.com/package/pi-memory-md) (VandeeFeng). All three share the same Letta lineage.

### What we have that others don't

| Feature                           | pi-context-repo | letta-code | pi-memory | pi-memory-md |
| --------------------------------- | :-------------: | :--------: | :-------: | :----------: |
| Git commits (not just writes)     |        ✓        |     ✓      |     ✗     |      ✓       |
| Pre-commit frontmatter validation |        ✓        |     ✓      |     ✗     |      ✗       |
| `read_only` protection            |        ✓        |     ✓      |     ✗     |      ✗       |
| Prompt drift detection            |        ✓        |     ✓      |     ✗     |      ✗       |
| Backup/restore snapshots          |        ✓        |     ✗      |     ✗     |      ✗       |
| Git worktree helpers              |        ✓        |     ✗      |     ✗     |      ✗       |

### Roadmap

Tracked in beads epic `dotfiles-4jfl`. Run `bd show dotfiles-4jfl` for full details.
