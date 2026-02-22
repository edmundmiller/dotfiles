# Dagster Module

NixOS service module for Dagster OSS data orchestration.

## Key Facts

- **3 systemd services**: `dagster-webserver`, `dagster-daemon`, `dagster-config` (oneshot)
- **Config flow**: nix options → `dagster.yaml` + `workspace.yaml` → `DAGSTER_HOME` (`/var/lib/dagster`)
- **Postgres**: peer auth via Unix socket — uses `postgres_url` with `?host=/run/postgresql`
- **Package**: `packages/dagster.nix` builds from PyPI, exposed as `pkgs.my.dagster`
- **Single daemon only**: dagster-daemon cannot be replicated
- **Code locations**: defined via `codeLocations` list; gRPC servers with `service.enable` get managed systemd services
- **Default webserver port**: 3000 (override with `webserver.port` if conflicting)

## Deployment Gotchas

- **Postgres URL format**: Must use `postgres_url` (not structured `postgres_db`) for Unix sockets. Structured config mangles the socket path into the database name (`"run/postgresql:5432/dagster"`)
- **Port conflicts**: NUC uses port 3001 because obsidian-sync container holds 3000
- **deploy-rs cache**: Use `nix run .#deploy-rs --refresh` to avoid stale flake eval

## Files

- `default.nix` — module definition
- `README.md` — human docs
- `AGENTS.md` — this file

## Related

- `modules/services/hass/default.nix` — postgres pattern reference
- `modules/services/gatus/default.nix` — tailscale serve + healthcheck pattern
