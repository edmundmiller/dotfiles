# Worklog: codex-home-assistant-mcp

Status: complete

## Objective

Connect Codex to the existing Home Assistant MCP endpoint through the Nix-managed dotfiles source without committing credentials. Stop when the scoped configuration checks pass, the local configuration is activated safely, `codex mcp` discovers the server, and a fresh Codex session performs one read-only Home Assistant state query.

## Decisions

- Prefer Home Assistant's built-in Streamable HTTP MCP server over a third-party server.
- Use Codex's native `bearer_token_env_var` after the user explicitly chose token authentication. Resolve the existing laptop-agent token reference with 1Password `op run`; never copy the token into Nix, Git, argv, logs, or `config.toml`.
- Make `codex-ha` start Codex with `tui_app_server` disabled so the MCP client inherits the 1Password-provided environment instead of reusing a persistent process that predates `HASS_TOKEN`. Default-enable 1Password's documented CLI app-integration environment switch while preserving an explicit caller override.
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
- Fresh official Home Assistant and Codex documentation confirms `/api/mcp` accepts `Authorization: Bearer <long-lived access token>` and Codex's supported config is `bearer_token_env_var`; `auth = "bearer"` is invalid and inline tokens are rejected.
- Existing 1Password reference `op://Agents/Hermes Laptop HA/credential` authenticated to the Home Assistant REST API with HTTP 200 while flowing only over stdin; no secret value was printed or stored in the checkout.
- Red: the focused MCP test failed because the source still emitted OAuth fields and had no `codex-ha` 1Password launcher. Green: the test passes with a single `HASS_TOKEN` bearer reference, preserved unrelated callback state, and behavioral launcher delegation to `op run`.
- Token revision checks pass: focused MCP behavior, seven Codex unit tests, Python compile/Ruff, ShellCheck, Nix parsing, and diff whitespace. Scoped `hey check --worktree` passed Darwin evaluation, formatting, hooks, tmux, package harness/policy, and ast-grep; it returned nonzero only for the unrelated pre-existing missing DJI Mic Mini check attribute.
- Live bearer dry-run: the candidate exactly matches the current parsed config plus only the managed Home Assistant field replacement; the callback and every unrelated server are preserved. No matching rebuild process is running, and the live file remains regular rather than a symlink.
- Local commit `e5645399e` contains the token-auth source revision; commit hooks passed and the worktree was clean afterward. No push or merge occurred.
- Narrow live apply atomically replaced only `~/.codex/config.toml`, preserved its observed mode and ownership, retained the callback and all unrelated runtime entries, and produced an idempotent follow-up dry-run. `codex mcp get homeassistant` reports the enabled Streamable HTTP server with `bearer_token_env_var: HASS_TOKEN` and no OAuth fields.
- At the first activation checkpoint, `codex-ha` timed out waiting for 1Password. No token was printed and no Home Assistant MCP request ran, so the read-only context proof was still unverified at that point.
- After interactive 1Password CLI authorization, the same reference returned Home Assistant REST HTTP 200. A minimal authenticated MCP initialize diagnostic reached `/api/mcp` without returning 401; response bodies and token values were discarded.
- A fresh Codex 0.147 process with `tui_app_server` disabled discovered and invoked `homeassistant/GetLiveContext`; Home Assistant rejected both the model-selected arguments and an explicit empty-object call, so neither failed call is treated as the state proof.
- Final live proof: fresh `codex-ha`/Codex completed `homeassistant/read_mcp_resource` for `homeassistant://assist/context-snapshot` with `mcp_servers.homeassistant.enabled_tools=[]`. The sanitized result reported `climate.main_floor` in state `cool`. No Home Assistant action/control tool was exposed or called, and the raw household snapshot was neither printed nor stored.
- Live `~/.codex/config.toml` remained a regular file with SHA-256 `168e0bb885466a0f7059c3ed9cd0fa7f4a0f87ec990e98f2e4a31df3aa62e97e`; repository state stayed clean until the final documented launcher hardening.
- Red/green launcher hardening: the focused MCP test failed before the launcher defaulted `OP_BIOMETRIC_UNLOCK_ENABLED=true` and inserted `--disable tui_app_server`, then passed with an explicit-caller override regression. ShellCheck and `git diff --check` pass.
- Final scoped `hey check --worktree` passed Darwin evaluation, formatting, pre-commit hooks, package harness/policy, and ast-grep. It returned nonzero only for unrelated existing checks: the tmux OpenCode session fixture produced no `oc-*` rows, and the DJI Mic Mini check attribute is absent from the flake.

## Reviews

Plan gate: repository pattern review and independent primary-source review completed. The final token path uses Home Assistant's maintained HTTP MCP endpoint, Codex's native bearer-token environment field, and the repository's existing 1Password reference; no MCP proxy was added.

Implementation review gate: the first scoped reconciler review returned blocking findings. After two hardening rounds, the terminal re-review reported no actionable findings. A fresh review of the token revision also found no actionable issue and confirmed no token enters source, config, argv, or logs; focused tests and manual TOML preservation probes passed.

## Feedback

None.

## Remaining work

None within the authorized scope. Broad Darwin activation, push, merge, and Home Assistant writes remain explicitly withheld.

## Commits

- `b51a10dac` — register Home Assistant MCP through the Codex source.
- `9ab467e2d` — harden narrow MCP reconciliation.
- `e5645399e` — replace OAuth with 1Password-backed bearer authentication.
- `6784c2813` — keep the Home Assistant MCP client in the token-bearing launcher process.

Push and merge are not authorized.
