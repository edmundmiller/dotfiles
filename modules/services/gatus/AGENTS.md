# Gatus

Uptime dashboard on port 8084, SQLite `/var/lib/gatus/data.db`, systemd
`DynamicUser`. The build produces a template; `ExecStartPre` replaces secret
placeholders into `/run/gatus/config.yaml`. Keep runtime credentials out of the
Nix store and diagnostics.

Service-owned endpoints come from their `registry.gatus`; only resources without
an owning module are hard-coded here. HTTP conditions commonly use
`[STATUS] == 200`, TCP `[CONNECTED] == true`. Registry `alerts = true` or local
`withAlerts` attaches providers; Telegram defaults to three failures and recovery.

Adding an alert provider affects options, `alertingConfig`, `alertsFor`,
and runtime secret substitution together.

Email and Notion default to the HA Runtime endpoint only. Keep their stable route
descriptions and opt-in durable producer handoff; `overlays/gatus` carries the
required patch. See [producer persistence and recovery](README.md#durable-gatus-handoff)
before changing identities or queue behavior. Separate local receivers own
external delivery queues, not HA diagnostics or notification polling. Email
uses the Family Ops Worker with a dedicated ingest token, not a Cloudflare admin
token. Preserve FIFO delivery across retries and restarts; recovery cannot pass
an unacknowledged failure. Delivery-health endpoints are dashboard-only.
Follow [the incident setup and recovery contract](README.md#notion-incidents-and-email-notifications)
for database schema, credential scope and ambiguous writes. On uncertain delivery,
retain queue state for operator reconciliation rather than recreating a page or
replaying a blocked email. Provider acceptance does not prove inbox delivery.

The dead-man's-switch uses `gatus-healthcheck-ping.timer/service`: `/start`
ping → local `/health` check → `/${EXIT_STATUS}` result. Start-ping failure
does not block the health command. The two-minute timer plus randomized delay
detects Gatus, host, or timer failure. `curl -fsS http://localhost:8084/health`
checks Gatus; starting the ping service also writes to Healthchecks and is not
a read-only diagnostic.

Run `hey check modules/services/gatus` for template, registry, or timer changes.
After deployment, use the local `/health` read first; invoke the ping unit only
when an external Healthchecks write is authorized and part of the test.
