# pi-context-repo

Git-backed memory filesystem extension for pi. `.pi/memory/` with `system/` pinned to system prompt.

## Key files

- `index.ts` — Full extension (1500+ lines): frontmatter parsing, git ops, tools, lifecycle hooks
- `package.json` — v0.2.0, pi extension entry

## Lineage

Derived from [letta-code memoryGit.ts](https://github.com/letta-ai/letta-code/blob/main/src/agent/memoryGit.ts). Sibling packages [pi-memory](https://www.npmjs.com/package/pi-memory) and [pi-memory-md](https://www.npmjs.com/package/pi-memory-md) share the same ancestry.

## Roadmap

Tracked in beads epic `dotfiles-4jfl`. Key open items:

- `dotfiles-zmpe` — Memory check reminder (P1)
- `dotfiles-4jfl.1` — Background reflection subagent (P1)
- `dotfiles-c365` — Deep /init-memory skill (P2)
- `dotfiles-jzjr` — Selective injection (P2)
- `dotfiles-4jfl.5` — Historical session analysis (P1)
- `dotfiles-1xqe` — Scratchpad tool (P3)
- `dotfiles-e8z3` — Per-section token budgets (P3)
