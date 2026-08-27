# Worklog: codex-home-assistant-mcp

Status: in-progress

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
- Red for the scoped recovery seam: `bash modules/agents/codex/test-seqera-mcp.sh` failed because `config/codex/reconcile_mcp.py` was absent and the module did not reference it.
- Green for the scoped recovery seam: the focused shell test passed, including dry-run, idempotency, and an untouched sibling-file sentinel; Python, ShellCheck, Ruff, nixfmt, and Nix parse checks passed.
- Live dry-run against `~/.codex/config.toml`: file hash and mode stayed unchanged; the parsed delta contained only `mcp_oauth_callback_port` and `mcp_servers.homeassistant`; all unrelated config values were preserved.
- `hey check --worktree` scoped to the four reconciler paths: all Darwin checks passed.
- Independent review found symlink-following, strict-header matching, unexecuted legacy cleanup, and non-atomic-write risks in the first reconciler draft.
- Hardened focused test passes: symlink and non-file targets are refused; trailing table comments are preserved without duplicate tables; normal activation removes only the intended legacy entries; replacement preserves mode and inode-swaps atomically; a simulated replace failure preserves the original and removes its temporary file.
- Residual review found valid TOML whitespace around table names, dots, and closing brackets was still unsupported. The matcher and regressions now cover main and nested managed tables with those forms; unsupported quoted-key forms fail closed before a write; the reconciled result must parse before replacement.
- A later boundary review found valid leading indentation before table headers was not treated as a section boundary. All managed, features, and legacy start/boundary patterns now accept leading spaces/tabs; the regression preserves an exact indented FFF block and proves parsed `rmcp_client` remains under `features`, not FFF.

## Reviews

Plan gate: repository pattern review and independent primary-source review completed. Home Assistant's official Codex example requires a matching callback port and OAuth client ID; both are reconciled without storing tokens in Nix.

Implementation review gate: the first scoped reconciler review returned blocking findings. After two hardening rounds, the terminal re-review reported no actionable findings; focused tests and manual TOML preservation probes passed.

## Feedback

None.

## Remaining work

- Broad Darwin activation remains explicitly withheld.
- Commit the reviewed Codex-only reconciler, apply it to `~/.codex/config.toml`, then complete OAuth, discovery, and a read-only `GetLiveContext` proof.

## Commits

Scoped local commit authorized; push and merge are not authorized.
