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
- `~/.claude/skills/{test-quality,github-cli-media,lore}` linked to shared catalog copies
- Darwin-only `~/.wakatime.cfg`

## Repo-local Claude plugin sources

These stay in the repo for development/reference, but installed plugins still live in `~/.claude/plugins/`:

- `config/claude/plugins/claude-lint/`
- `config/claude/plugins/github/`
- `config/claude/plugins/json-to-toon/`

## Notes

- Shared skills live in `~/.agents/skills`; Claude receives only the
  `test-quality`, `github-cli-media`, and `lore` links while activation removes
  other Claude skill copies
- Project-local skills belong in `.agents/skills/`
- If Claude reports settings schema errors, check `config/claude/settings.json`
