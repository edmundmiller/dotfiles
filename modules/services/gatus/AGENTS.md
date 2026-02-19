# Gatus Module - Agent Guide

## Purpose

Uptime monitoring dashboard for NUC services. Checks HTTP/TCP endpoints every 60-120s, stores results in SQLite, serves web UI.

## Module Structure

```
modules/services/gatus/
├── default.nix   # Module definition
├── README.md     # Human docs
└── AGENTS.md     # This file
```

## Key Facts

- **Port:** 8084 (configurable via `cfg.port`)
- **Storage:** SQLite at `/var/lib/gatus/data.db`
- **Systemd:** `DynamicUser = true` — no manual user creation needed
- **Config:** Generated as JSON from Nix attrset via `pkgs.writeText`
- **NixOS-only:** Wrapped in `optionalAttrs (!isDarwin)`
- **Tailscale serve:** Optional, creates `gatus-tailscale-serve.service`

## Monitored Endpoints

| Service          | Group          | URL                         | Protocol           |
| ---------------- | -------------- | --------------------------- | ------------------ |
| Home Assistant   | Smart Home     | localhost:8123/api/         | HTTP               |
| Homebridge       | Smart Home     | localhost:8581              | HTTP               |
| Matter Server    | Smart Home     | localhost:5580              | TCP                |
| Jellyfin         | Media          | localhost:8096/health       | HTTP               |
| Sonarr           | Media          | localhost:8989/ping         | HTTP               |
| Radarr           | Media          | localhost:7878/ping         | HTTP               |
| Prowlarr         | Media          | localhost:9696/ping         | HTTP               |
| PostgreSQL       | Infrastructure | localhost:5432              | TCP                |
| Tailscale        | Infrastructure | localhost:41112/healthz     | HTTP               |
| OpenClaw Gateway | Infrastructure | localhost:18789             | HTTP (conditional) |
| Audiobookshelf   | Media          | localhost:13378/healthcheck | HTTP (conditional) |

## Adding New Endpoints

Add to the `endpoints` list in `default.nix`. HTTP endpoints use `[STATUS] == 200`, TCP use `[CONNECTED] == true`.

For conditional endpoints (only when another module is enabled):

```nix
++ optionals config.modules.services.foo.enable [ { ... } ]
```

## Related Files

- `hosts/nuc/default.nix` — Enables module with `tailscaleService.enable = true`
- `modules/services/AGENTS.md` — Tailscale serve pattern docs
