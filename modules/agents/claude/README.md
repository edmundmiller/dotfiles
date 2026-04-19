# Claude CLI Module

Minimal nix-darwin wiring for Claude Code. This mainly exists so native Claude Code and `acpx claude` can share the same baseline Claude runtime config.

## Enable

```nix
modules.agents.claude.enable = true;
```

## What it manages

- `claude-code` package
- `~/.claude/settings.json` from `config/claude/settings.json`
- `~/.claude/CLAUDE.md` built from `config/agents/rules/*.md`
- `~/.claude/agents/` from `config/agents/modes/`
- `~/.claude/skills` → `~/.agents/skills`
- Darwin-only `~/.wakatime.cfg`

## Repo-local Claude plugin sources

These stay in the repo for development/reference, but installed plugins still live in `~/.claude/plugins/`:

- `config/claude/plugins/claude-lint/`
- `config/claude/plugins/github/`
- `config/claude/plugins/json-to-toon/`

## Notes

- Shared skills and modes live under `config/agents/`
- Project-local skills belong in `.agents/skills/`
- If Claude reports settings schema errors, check `config/claude/settings.json`
