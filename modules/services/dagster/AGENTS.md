# Dagster Module

NixOS service module for Dagster OSS data orchestration.

## Key Facts

- **3 systemd services**: `dagster-webserver`, `dagster-daemon`, `dagster-config` (oneshot)
- **Config flow**: nix options → `dagster.yaml` + `workspace.yaml` → `DAGSTER_HOME` (`/var/lib/dagster`)
- **Postgres**: peer auth via `services.postgresql`, no password needed
- **Package**: `packages/dagster.nix` builds from PyPI, exposed as `pkgs.my.dagster`
- **Single daemon only**: dagster-daemon cannot be replicated
- **Code locations**: defined via `codeLocations` list; code servers run separately (not managed by this module)

## Files

- `default.nix` — module definition
- `README.md` — human docs
- `AGENTS.md` — this file

## Related

- `modules/services/hass/default.nix` — postgres pattern reference
- `modules/services/gatus/default.nix` — tailscale serve + healthcheck pattern
