# Codex module

Nix/Home Manager owns the foreground CLI and configuration bootstrap. The remote
control daemon uses a separate official-installer-managed writable binary under
`~/.codex/packages/standalone`. Keep both installations and Nix's PATH precedence.

`config/codex/config.toml` seeds writable `~/.codex/config.toml`; subsequent
settings are user-managed except enabled MCP blocks. Rules are writable seeds;
`agents/*.toml` and the shared core `AGENTS.md` are managed. OAuth, sessions, and
history remain runtime-owned. Shared skills use `~/.agents/skills`; Codex-only
skills use `meta.targets = [ "codex" ]`.

## MCP and permissions

- The host catalog `modules.agents.mcp` owns server registrations in writable
  `~/.codex/config.toml`, preserving unrelated config and runtime-owned auth.
  See [ADR 0013](../../../docs/adr/0013-host-owned-agent-mcp.md) for adapter ownership.
  Seqera OAuth is user-managed (`codex mcp login seqera`); inspect with
  `codex mcp get seqera`.
- `homeAssistantMcp` supplies the credential-specific `codex-ha` launcher.
  Register `homeassistant` separately in the host catalog with
  `bearerTokenEnv = "HASS_TOKEN"`. The adapter renders `bearer_token_env_var`.
  `codex-ha` resolves `secretReference` using `op run` into child-only
  `HASS_TOKEN`. Keep tokens out of Nix, Git, argv, and config.
  Persistent `tui_app_server` is disabled so the client inherits that environment;
  explicit `OP_BIOMETRIC_UNLOCK_ENABLED` is preserved.
- HA integration proof is a fresh `codex-ha` read of
  `homeassistant://assist/context-snapshot` with action tools disabled.
- Trusted repository `.codex/config.toml` owns repository permissions. Named
  `default_permissions` profiles use `:minimal = "read"` and explicit roots;
  legacy `sandbox_mode` takes precedence and cannot remain alongside them.
  NUC needs read access to the standalone tree for bundled Bubblewrap.
- Local filesystem/network profiles do not constrain MCP, hooks, plugins, or
  browser capabilities; scope those separately.

## Sources and checks

Model defaults and delegation policy live in `config/codex/config.toml` and
`config/codex/agents/`, not in this router. The writable live config may differ;
`codex features list` shows effective feature state.

Focused checks: `python3 -m unittest tests.test_codex_model_config` and
`uv run --with json5 --with tomlkit python -m unittest tests.test_agent_mcp`.
Remote-control bootstrap, pairing,
and recovery: [NUC runbook](../../../docs/runbooks/deploy-nuc.md#codex-remote-control).
Use the Codex unit test for model/profile/config contracts and the shared MCP
test for host registration. Live OAuth, HA reads, pairing, and repair commands verify
separate runtime paths and must not be substituted for either source check.
