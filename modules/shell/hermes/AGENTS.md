# Hermes Shell Module

This module bootstraps Edmund's local Hermes CLI home and keeps it writable.

## Key rules

- Edit `modules/shell/hermes/default.nix` for package/bootstrap behavior.
- Edit `config/hermes/` for seeded user-facing files (`SOUL.md`, `config.yml`, skins).
- Do not assume files under `$HERMES_HOME` are store symlinks; this module intentionally writes normal files so the CLI can mutate them.
- Keep `hermes acp` working on laptop installs. If the upstream package omits ACP extras, wrap the package here rather than telling the user to `pip install` into an ad-hoc environment.

## Activation behavior

The home-manager activation step:

1. resolves `HERMES_HOME`
2. migrates `~/.hermes` if needed
3. writes `SOUL.md`
4. copies repo-managed skins
5. merges declarative config overlays into a writable `config.yaml`
6. materializes managed secrets into `$HERMES_HOME/.env`

## Validation

After changing this module, prefer validating with a Nix eval/build of the Hermes package or the host config using `hey re` for Darwin hosts.
