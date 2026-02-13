# Codex Module

Manages `~/.codex/` config via nix-darwin.

## Files

- `config.toml` — symlinked from `config/codex/config.toml`
- `AGENTS.md` — built from concatenated `config/agents/rules/*.md` (shared w/ Claude, OpenCode)
- `rules/` — sandbox allow-rules, symlinked from `config/codex/rules/`

## Not Managed by Nix

- `auth.json` — OAuth credentials (user-managed)
- `skills/` — user-managed skills directory
- `sessions/`, `history.jsonl` — runtime data
