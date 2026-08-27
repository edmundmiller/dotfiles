# Worklog: codex-home-assistant-mcp

Status: blocked

## Objective

Connect Codex to the existing Home Assistant MCP endpoint through the Nix-managed dotfiles source without committing credentials. Stop when the scoped configuration checks pass, the local configuration is activated safely, `codex mcp` discovers the server, and a fresh Codex session performs one read-only Home Assistant state query.

## Decisions

- Prefer Home Assistant's built-in Streamable HTTP MCP server over a third-party server.
- Prefer Codex-managed OAuth because both Home Assistant and Codex officially support it and it avoids duplicating the existing long-lived access token.
- Scope authority to local implementation, activation, and read-only verification; do not push or merge.
- Do not activate the pending broad Darwin generation; it includes unrelated Hermes, launchd, and agent dependency changes.

## Evidence

- Checkout: `/Users/emiller/.codex/worktrees/5a18/dotfiles`; detached at `17825e14229cdecbc99dcd7c8580af35cf667d16`; clean before edits; no rebase, merge, or concurrent mutation detected.
- Host: `MacTraitor-Pro.local`, Darwin arm64.
- Existing endpoint: `https://homeassistant.cinnamon-rooster.ts.net/api/mcp` in `modules/agents/omp/default.nix`.
- Official Home Assistant MCP documentation: built-in `/api/mcp`, Streamable HTTP, OAuth supported.
- Official Codex MCP documentation: Streamable HTTP and OAuth supported; configuration lives under `[mcp_servers.<name>]` and `codex mcp login <name>` stores credentials outside declarative config.
- Red: `bash modules/agents/codex/test-seqera-mcp.sh` failed because the managed Home Assistant block and OAuth callback settings were absent.
- Green: `bash modules/agents/codex/test-seqera-mcp.sh` passed after adding host-scoped reconciliation.
- `python3 -m unittest tests.test_codex_model_config`: 7 tests passed.
- `hey check --worktree modules/agents/codex/default.nix modules/agents/codex/AGENTS.md modules/agents/codex/test-seqera-mcp.sh hosts/mactraitorpro/default.nix tests/test_codex_model_config.py`: all Darwin checks passed.
- `hey re dry-activate`: unsupported by the installed nix-darwin (`unknown option 'dry-activate'`); no activation occurred.
- `hey re build`: exposed 55 pending derivations including unrelated Hermes and launchd changes; the build-only check was stopped after several minutes and is not treated as passed.

## Reviews

Plan gate: repository pattern review and independent primary-source review completed. Home Assistant's official Codex example requires a matching callback port and OAuth client ID; both are reconciled without storing tokens in Nix.

## Feedback

None.

## Remaining work

- Broad Darwin activation is explicitly withheld.
- Until a Codex-only activation is available, `codex mcp login homeassistant`, MCP discovery, and a read-only `GetLiveContext` proof remain blocked.

## Commits

Scoped local commit authorized; push and merge are not authorized.
