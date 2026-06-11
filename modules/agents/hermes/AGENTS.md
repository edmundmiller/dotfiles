# Hermes Agent Module

This NixOS-only module bootstraps a managed Hermes Runtime Root for declarative Hermes Gateway/runtime use.

## Key rules

- Edit `modules/agents/hermes/default.nix` for package/bootstrap behavior.
- Edit `config/hermes/` for seeded user-facing files (`SOUL.md`, `config.yml`, skins).
- Do not assume files under `$HERMES_HOME` are store symlinks; this module intentionally writes normal files so the CLI can mutate them.
- Do not add macOS/Desktop app installation here; install Hermes Desktop manually/upstream on Macs for now.

## Activation behavior

The home-manager activation step:

1. resolves `HERMES_HOME`
2. migrates `~/.hermes` if needed
3. writes `SOUL.md`
4. copies repo-managed skins
5. merges declarative config overlays into a writable `config.yaml`
6. materializes managed secrets into `$HERMES_HOME/.env`

## MCP servers and secrets

Hermes MCP server definitions that are safe to commit belong in `config/hermes/config.yml` under `mcp_servers`. Keep them frictionless by declaring the server once in the repo-managed base config and using Hermes env interpolation for secrets, e.g. `${GITHUB_TOKEN}`. Hermes loads `$HERMES_HOME/.env` and interpolates those variables before starting stdio MCP servers.

Do **not** commit literal tokens in `config/hermes/config.yml` or write secrets into `$HERMES_HOME/config.yaml`. Put host-specific secret materialization in the host's `modules.agents.hermes.secretReferences` so activation writes `$HERMES_HOME/.env` from 1Password. Example pattern for GitHub MCP:

```nix
modules.agents.hermes.secretReferences = {
  GITHUB_TOKEN = "op://Private/GitHub Personal Access Token/credential";
};
```

```yaml
mcp_servers:
  github:
    env:
      GITHUB_PERSONAL_ACCESS_TOKEN: "${GITHUB_TOKEN}"
```

Use the MCP server's expected environment variable name on the left and the Hermes `.env` variable on the right. Prefer generic `.env` names like `GITHUB_TOKEN` unless the upstream docs require otherwise.

## Validation

After changing this module, prefer validating with a Nix eval/build of the Hermes package or the target NixOS host config.

A warning-only `hermes-runtime-drift` prek pre-push hook checks whether mutable `$HERMES_HOME` looks out of sync with repo-managed config, SOUL, skins, hooks, or plugins. It must never mutate `$HERMES_HOME`; fix drift with `hey re`.

## Provider Validation

Run `hermes doctor` to validate the inference fallback chain and API connectivity.
