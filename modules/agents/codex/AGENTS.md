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

- `seqeraMcp.enable` registers `https://mcp.seqera.io/mcp` with `rmcp_client`.
  OAuth is user-managed (`codex mcp login seqera`); inspect with `codex mcp get seqera`.
- `homeAssistantMcp` registers the existing HA integration. `codex-ha` resolves
  `secretReference` using `op run` into child-only `HASS_TOKEN`, using native
  `bearer_token_env_var`. Keep tokens out of Nix, Git, argv, and config.
  Persistent `tui_app_server` is disabled so the client inherits that environment;
  explicit `OP_BIOMETRIC_UNLOCK_ENABLED` is preserved.
- HA integration proof is a fresh `codex-ha` read of
  `homeassistant://assist/context-snapshot` with action tools disabled.
- `python3 config/codex/reconcile_mcp.py --dry-run "$HOME/.codex/config.toml" 0 1`
  previews the narrow MacTraitorPro MCP repair without printing config. Applying
  it changes live state and requires authorization.
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
`bash modules/agents/codex/test-seqera-mcp.sh`. Remote-control bootstrap, pairing,
and recovery: [NUC runbook](../../../docs/runbooks/deploy-nuc.md#codex-remote-control).
