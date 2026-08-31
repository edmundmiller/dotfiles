---
purpose: Maintain the legacy startup bundle during per-runtime thin-core migration.
applies_to: Compatibility changes for Claude, Pi, or OpenCode only.
entrypoint: Prefer a skill, scoped AGENTS.md, canonical doc, or deterministic check first.
verification: Run check-agent-rules and the affected runtime wiring test.
update_when: A legacy runtime adopts the thin core or still requires a global invariant.
---

# Legacy agent rules

These numbered files remain a compatibility bundle. Do not add task procedures,
learned preferences, or repository facts here. OMP and Codex use
`config/agents/core.md` instead.

## How It Works

Nix reads `*.md` files (excluding `AGENTS.md`), sorts by filename, concatenates with `\n\n` separators:

- `~/.claude/CLAUDE.md` — via `modules/agents/claude/default.nix`
- `~/.pi/agent/AGENTS.md` — via `modules/agents/pi/default.nix`
- `~/.config/opencode/rules/` — via `modules/agents/opencode/default.nix` (symlinked as individual files)

## Design Principles

- **Compatibility only** — remove a runtime from this bundle after its thin
  migration passes runtime-specific evaluation.
- **Every token costs** — these are injected into every legacy-runtime conversation. Trim aggressively.
- **Rules, not reference** — behavioral directives only. Tutorials and examples belong in skills.
- **Agent-agnostic** — no agent-specific tools/plugins (e.g. Claude MCP plugins). Those go in agent modules.
- **Numbering = ordering** — gaps are fine, don't renumber existing files.

## Discovering Rules

Each rule file has YAML frontmatter with a `purpose:` field. List them: `head -3 config/agents/rules/[0-9]*.md | grep purpose:`

## Changing a legacy rule

1. Prove why the behavior cannot live in a skill, scoped router, hook, lint, or test.
2. Keep the change to a non-detectable universal invariant.
3. Run `python3 bin/check-agent-rules --json` and the affected runtime checks.
4. Rebuild with `hey re` and read back the generated runtime instructions.
