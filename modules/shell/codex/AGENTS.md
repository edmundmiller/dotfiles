# Codex Module

Manages `~/.codex/` config via nix-darwin.

## Files

- `config.toml` — bootstrapped from `config/codex/config.toml` if missing; kept as a writable local file so Codex can mutate settings
- `AGENTS.md` — built from concatenated `config/agents/rules/*.md` (shared w/ Claude, OpenCode)
- `rules/` — sandbox allow-rules, symlinked from `config/codex/rules/`

## Not Managed by Nix

- `auth.json` — OAuth credentials (user-managed)
- `skills/` — user-managed skills directory
- `sessions/`, `history.jsonl` — runtime data
- `config.toml` after bootstrap — user-managed and writable
