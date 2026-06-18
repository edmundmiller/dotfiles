# Codex Module

Manages `~/.codex/` config via nix-darwin.

## Files

- `config.toml` — bootstrapped from `config/codex/config.toml` if missing; kept as a writable local file so Codex can mutate settings
- `AGENTS.md` — built from concatenated `config/agents/rules/*.md` (shared w/ Claude, OpenCode)
- `rules/` — sandbox allow-rules, bootstrapped into `~/.codex/rules/` during activation as local writable files

## Not Managed by Nix

- `auth.json` — OAuth credentials (user-managed)
- `sessions/`, `history.jsonl` — runtime data
- `config.toml` after bootstrap — user-managed and writable

## Skills

Codex-specific generated skills sync to `~/.codex/skills/` when `modules.agents.codex.enable = true`.
Cross-agent generated skills also sync to `~/.agents/skills/` when any local agent module is enabled.
