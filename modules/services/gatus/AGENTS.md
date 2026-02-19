# Gatus Module - Agent Guide

## Purpose

Uptime monitoring dashboard for NUC services. Checks HTTP/TCP endpoints every 60-120s, stores results in SQLite, serves web UI. Alerts via Telegram when services go down. Pings healthchecks.io as a dead man's switch.

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
- **Config:** Template at build time, secrets injected at runtime via `ExecStartPre`
- **Runtime config:** `/run/gatus/config.yaml` (secrets replaced from template)
- **Systemd:** `DynamicUser = true` — no manual user creation needed
- **NixOS-only:** Wrapped in `optionalAttrs (!isDarwin)`

## Secret Injection

The config template contains `__TELEGRAM_TOKEN__` placeholder. `ExecStartPre` copies the template to `/run/gatus/` and uses `sed` to replace placeholders with values read from agenix secret files. This keeps secrets out of the nix store.

## Alerting

- **Telegram:** Sends alerts to a chat when endpoints fail 3x in a row, and on recovery
- **Dead man's switch:** `gatus-healthcheck-ping.timer` curls healthchecks.io every 2 min. If NUC/Gatus dies, healthchecks.io alerts externally.

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

Add to the `endpoints` list in `default.nix`. HTTP endpoints use `[STATUS] == 200`, TCP use `[CONNECTED] == true`. Alerts are auto-attached to all endpoints via `withAlerts`.

For conditional endpoints (only when another module is enabled):

```nix
++ optionals config.modules.services.foo.enable [ { ... } ]
```

## Adding New Alert Providers

1. Add options under `cfg.alerting.<provider>`
2. Add provider config to `alertingConfig` (with placeholder for secrets)
3. Add `{ type = "<provider>"; }` to `endpointAlerts`
4. Add sed replacement in `ExecStartPre` for any secret placeholders

## Related Files

- `hosts/nuc/default.nix` — Enables module with alerting + healthcheck config
- `hosts/nuc/secrets/secrets.nix` — Agenix secret declarations
- `hosts/nuc/secrets/telegram-bot-token.age` — Encrypted bot token
- `modules/services/AGENTS.md` — Tailscale serve pattern docs
