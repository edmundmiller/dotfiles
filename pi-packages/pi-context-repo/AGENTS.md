# pi-context-repo

Git-backed memory filesystem extension for pi. `.pi/memory/` with `system/` pinned to system prompt.

## Key files

- `index.ts` — Full extension (1500+ lines): frontmatter parsing, git ops, tools, lifecycle hooks
- `package.json` — v0.2.0, pi extension entry

## Lineage

Derived from Letta's memory stack, especially:

- [memoryGit.ts](https://github.com/letta-ai/letta-code/blob/main/src/agent/memoryGit.ts)
- `memoryFilesystem.ts` tree rendering limits
- `cli/helpers/memoryReminder.ts` reflection trigger model

Sibling packages [pi-memory](https://www.npmjs.com/package/pi-memory) and [pi-memory-md](https://www.npmjs.com/package/pi-memory-md) share the same ancestry.

## Reminder model

Implemented subset:

- `step-count` memory reminders
- `compaction-event` memory reminders via `auto_compaction_start`
- `off` mode to disable automatic reminders
- `/sleeptime` command for reminder configuration

Invariants:

- reminders are injected as system reminders, never user messages
- step-count reminders fire deterministically from saved settings
- compaction reminders queue once and drain on the next turn
- reminder docs/tests should stay aligned with runtime behavior

## Roadmap

Tracked in beads epic `dotfiles-4jfl`. Key open items:

- `dotfiles-4jfl.1` — Background reflection subagent / worker (P1)
- `dotfiles-c365` — Deep /init-memory skill (P2)
- `dotfiles-jzjr` — Selective injection (P2)
- `dotfiles-4jfl.5` — Historical session analysis (P1)
- `dotfiles-1xqe` — Scratchpad tool (P3)
- `dotfiles-e8z3` — Per-section token budgets (P3)
- Future reminder-port gaps — reminder catalog/state, handled command I/O reminders, toolset-change reminders, mode-scoped reminders
