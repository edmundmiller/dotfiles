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

## Plugins are retired

The repository no longer ships Claude Code plugin sources, marketplaces, enabled
plugins, or plugin installation hooks. Existing host plugin caches are not
deleted by this source change. The settings bootstrap drops the old plugin
declarations on the next authorized rebuild.

## Notes

- Shared skills live in `~/.agents/skills`; Claude receives only the
  `test-quality`, `github-cli-media`, `lore`, and `pe-verify` links while
  activation removes other Claude skill copies
- Project-local skills belong in `.agents/skills/`
- If Claude reports settings schema errors, check `config/claude/settings.json`
