---
purpose: Define ownership and recovery for Codex CLI configuration and remote control.
applies_to: Changes to the Codex package, Home Manager module, or NUC remote-control setup.
entrypoint: modules/agents/codex/default.nix
verification: bash modules/agents/codex/test-seqera-mcp.sh; command -v codex; codex app-server daemon version
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
- `config.toml` after bootstrap — user-managed and writable, except enabled host integrations such as `seqeraMcp`, which reconcile their MCP block and prerequisite feature
- `packages/standalone/` — mutable daemon runtime installed and updated by the official Codex installer

## Seqera MCP

Set `modules.agents.codex.seqeraMcp.enable = true` only on hosts that need it.
Activation registers `https://mcp.seqera.io/mcp` and enables `rmcp_client`.
OAuth remains user-managed: after rebuilding that host, run `codex mcp login seqera`.
On Seqeratop, verify the registration with `codex mcp get seqera`.

## Project Permissions

Put repository-specific policies in the repository's trusted `.codex/config.toml`.
Use a named `default_permissions` profile with `:minimal = "read"` and explicit
absolute or `~/...` roots when reads must be confined. Legacy `sandbox_mode`
settings take precedence over named profiles and must not remain in loaded config.
On the NUC, grant read access to `~/.codex/packages/standalone` so bundled
Bubblewrap can launch the installer-managed command runtime.

Permission profiles constrain local command filesystem and network access only.
Scope or disable filesystem-capable MCP servers separately. Hooks, plugins, browser
tools, and remote MCP services remain independent capabilities.

## NUC Remote Control

Keep both installations: the foreground CLI remains Nix-managed, while the daemon uses the
installer-managed writable path. Do not put `$HOME/.local/bin` before the Nix profile, remove
`pkgs.llm-agents.codex`, or manage the standalone tree with Nix.

Follow the [NUC deployment runbook](../../../docs/runbooks/deploy-nuc.md#codex-remote-control)
for bootstrap, pairing, verification, and recovery.

## Skills

Codex reads shared generated skills from `~/.agents/skills/`.
`~/.codex/skills/` is only for Codex-specific skills with `meta.targets = [ "codex" ]`.
