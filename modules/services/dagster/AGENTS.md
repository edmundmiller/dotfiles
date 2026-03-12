# Dagster Module Family

Shared Dagster OSS stack + repo-specific code locations.

## Files

- `default.nix` — shared Dagster control plane: postgres wiring, `dagster-config`, `dagster-webserver`, `dagster-daemon`, generated `dagster.yaml` + `workspace.yaml`, generic `codeLocations` support
- `bugster.nix` — Bugster code location on gRPC port 4000; clones repo, writes `bugster.toml`, starts `dagster-code-bugster`
- `finances.nix` — Finances code location on gRPC port 4010; clones repo, injects OP token env, starts `dagster-code-finances`
- `README.md` — human overview
- `AGENTS.md` — this file

## Mental model

One Dagster deployment, not one process:

- one `dagster-webserver`
- one `dagster-daemon`
- many `dagster-code-*` services

Each code location is its own process. That's normal Dagster OSS prod shape.

## Gotchas

- `dagster-daemon` must stay singleton
- `workspace.yaml` is generated from `modules.services.dagster.codeLocations`
- if a code location is missing on host, inspect rendered systemd units first; if the unit is absent, activation/eval was stale, not Dagster runtime
- deploy-rs can evaluate stale flake state; prefer `nix run .#deploy-rs --refresh -- .#nuc ...`
- NUC webserver uses port `3001`, not `3000`

## Related

- `hosts/nuc/default.nix` — enables dagster + bugster + finances
- `docs/finances-dagster-nuc.md` — finances ops notes
- `modules/services/bugster/README.md` — older bugster-specific notes
