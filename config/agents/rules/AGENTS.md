# Agent Rules Directory

Numbered markdown files concatenated into each agent's system prompt at build time.

## How It Works

Nix reads `*.md` files (excluding `AGENTS.md`), sorts by filename, concatenates with `\n\n` separators:

- `~/.claude/CLAUDE.md` — via `modules/agents/claude/default.nix`
- `~/.pi/agent/AGENTS.md` — via `modules/agents/pi/default.nix`
- `~/.config/opencode/rules/` — via `modules/agents/opencode/default.nix` (symlinked as individual files)

## Design Principles

- **Every token costs** — these are injected into every conversation. Trim aggressively.
- **Rules, not reference** — behavioral directives only. Tutorials and examples belong in skills.
- **Agent-agnostic** — no agent-specific tools/plugins (e.g. Claude MCP plugins). Those go in agent modules.
- **Numbering = ordering** — gaps are fine, don't renumber existing files.

## Discovering Rules

Each rule file has YAML frontmatter with a `purpose:` field. List them: `head -3 config/agents/rules/[0-9]*.md | grep purpose:`

## Adding a Rule

1. Pick next number: `<NN>-<name>.md`
2. Add YAML frontmatter with `purpose:` field
3. Keep it short — if >500B, ask whether a skill would be better
4. Rebuild: `hey re`
