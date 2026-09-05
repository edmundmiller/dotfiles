# Gatus

Uptime dashboard on port 8084, SQLite `/var/lib/gatus/data.db`, systemd
`DynamicUser`. The build produces a template; `ExecStartPre` replaces secret
placeholders into `/run/gatus/config.yaml`. Keep Telegram tokens out of the
Nix store and diagnostics.

Service-owned endpoints come from their `registry.gatus`; only resources without
an owning module are hard-coded here. HTTP conditions commonly use
`[STATUS] == 200`, TCP `[CONNECTED] == true`. Registry `alerts = true` or local
`withAlerts` attaches providers; Telegram defaults to three failures and recovery.

Adding an alert provider affects options, `alertingConfig`, `endpointAlerts`,
and runtime secret substitution together.

The dead-man's-switch uses `gatus-healthcheck-ping.timer/service`: `/start`
ping → local `/health` check → `/${EXIT_STATUS}` result. Start-ping failure
does not block the health command. The two-minute timer plus randomized delay
detects Gatus, host, or timer failure. `curl -fsS http://localhost:8084/health`
checks Gatus; starting the ping service also writes to Healthchecks and is not
a read-only diagnostic.
