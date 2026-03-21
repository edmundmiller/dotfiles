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
- reflection bundle preparation under `.pi/reflection-runtime/`
- optional event-bus launch contract on `pi-context-repo:reflection-launch`
- `/reflect` command for explicit manual/background reflection handoff

Invariants:

- automatic reminders are injected as system reminders, never user messages
- step-count reminders fire deterministically from saved settings
- compaction reminders queue once and drain on the next turn
- reflection bundles are sidecar runtime artifacts, not memory repo content
- event-bus launch handoff must degrade cleanly to reminder fallback when no listener accepts it
- reminder docs/tests should stay aligned with runtime behavior

## Roadmap

Tracked in beads epic `dotfiles-4jfl`. Key open items:

Background reflection is now split into two layers:

- implemented here: transcript bundle prep, launch contract, fallback reminder handoff
- still open: a real autonomous worker that accepts the launch event and performs memory edits out-of-band

- `dotfiles-4jfl.1` — Background reflection worker implementation beyond the event-bus launch contract (P1)
- `dotfiles-c365` — Deep /init-memory skill (P2)
- `dotfiles-jzjr` — Selective injection (P2)
- `dotfiles-4jfl.5` — Historical session analysis (P1)
- `dotfiles-1xqe` — Scratchpad tool (P3)
- `dotfiles-e8z3` — Per-section token budgets (P3)
- Future reminder-port gaps — reminder catalog/state, handled command I/O reminders, toolset-change reminders, mode-scoped reminders
