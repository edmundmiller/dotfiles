---
purpose: Explain the Claude CLI module and its managed files.
applies_to: Enabling or maintaining Claude Code in this dotfiles repo.
entrypoint: Set modules.agents.claude.enable and rebuild.
verification: Confirm the managed Claude files after rebuilding.
update_when: Claude module behavior or managed paths change.
---

# Claude CLI Module

Minimal nix-darwin wiring for Claude Code. This mainly exists so native Claude Code and `acpx claude` can share the same baseline Claude runtime config.

## Enable

```nix
modules.agents.claude.enable = true;
```

## What it manages

- `claude-code` package
- `~/.claude/settings.json` from `config/claude/settings.json`
- `~/.claude/CLAUDE.md` from the bounded `config/agents/core.md`
- `~/.claude/agents/` from `config/agents/modes/`
- `~/.claude/skills/{test-quality,github-cli-media,lore,pe-verify}` linked to shared catalog copies

## Plugin policy

The template enables `pstack@cursor-plugins` and points `cursor-plugins` at the
Nix-pinned marketplace. The settings bootstrap keeps other plugin and marketplace
entries already in `~/.claude/settings.json`. Template keys win. Retired DuckDB,
Plannotator, and WakaTime entries are removed on each bootstrap. This module
does not install any marketplace other than that pstack link.

## Notes

- Shared skills live in `~/.agents/skills`; Claude receives only the
  `test-quality`, `github-cli-media`, `lore`, and `pe-verify` links while
  activation removes other Claude skill copies
- Project-local skills belong in `.agents/skills/`
- If Claude reports settings schema errors, check `config/claude/settings.json`
