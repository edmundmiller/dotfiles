# Agent Rules Directory

Numbered markdown files concatenated into each agent's system prompt at build time.

## How It Works

Nix reads `*.md` files (excluding `AGENTS.md`), sorts by filename, concatenates with `\n\n` separators:

- `~/.claude/CLAUDE.md` — via `modules/shell/claude/default.nix`
- `~/.pi/agent/AGENTS.md` — via `modules/shell/pi/default.nix`
- `~/.config/opencode/rules/` — symlinked as individual files

## Design Principles

- **Every token costs** — these are injected into every conversation. Trim aggressively.
- **Rules, not reference** — behavioral directives only. Tutorials and examples belong in skills.
- **Agent-agnostic** — no agent-specific tools/plugins (e.g. Claude MCP plugins). Those go in agent modules.
- **Numbering = ordering** — gaps are fine, don't renumber existing files.

## Current Files

| File                         | Purpose                      |
| ---------------------------- | ---------------------------- |
| `01-tone-and-style`          | Concision directive          |
| `02-critical-instructions`   | File editing, output format  |
| `03-version-control`         | Worktrees, selective staging |
| `04-code-search`             | ast-grep preference          |
| `05-testing-philosophy`      | Spec + regression tests      |
| `06-development-preferences` | Persistence, philosophy      |
| `07-skill-locations`         | Where to create skills       |
| `08-context-efficiency`      | Filter at source             |

## Adding a Rule

1. Pick next number: `09-<name>.md`
2. Keep it short — if >500B, ask whether a skill would be better
3. Rebuild: `hey re`
