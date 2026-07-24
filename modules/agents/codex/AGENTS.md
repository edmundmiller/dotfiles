---
purpose: Define ownership and recovery for Codex CLI configuration and remote control.
applies_to: Changes to the Codex package, Home Manager module, or NUC remote-control setup.
entrypoint: modules/agents/codex/default.nix
verification: command -v codex; codex app-server daemon version
update_when: Codex installation paths, ownership, bootstrap, or recovery behavior changes.
---

# Codex Module

Nix/Home Manager owns the writable configuration bootstrap and the foreground CLI.
Remote control deliberately uses a second, installer-managed Codex binary for its daemon.

## Files

- `config.toml` — bootstrapped from `config/codex/config.toml` if missing; kept as a writable local file so Codex can mutate settings
- `AGENTS.md` — built from concatenated `config/agents/rules/*.md` (shared w/ Claude, OpenCode)
- `rules/` — sandbox allow-rules, bootstrapped into `~/.codex/rules/` during activation as local writable files

## Not Managed by Nix

- `auth.json` — OAuth credentials (user-managed)
- `sessions/`, `history.jsonl` — runtime data
- `config.toml` after bootstrap — user-managed and writable
- `packages/standalone/` — mutable daemon runtime installed and updated by the official Codex installer

## NUC Remote Control

Keep both installations: the foreground CLI remains Nix-managed, while the daemon uses the
installer-managed writable path. Do not put `$HOME/.local/bin` before the Nix profile, remove
`pkgs.llm-agents.codex`, or manage the standalone tree with Nix.

Follow the [NUC deployment runbook](../../../docs/runbooks/deploy-nuc.md#codex-remote-control)
for bootstrap, pairing, verification, and recovery.

## Skills

Codex reads shared generated skills from `~/.agents/skills/`.
`~/.codex/skills/` is only for Codex-specific skills with `meta.targets = [ "codex" ]`.
