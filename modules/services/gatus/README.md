---
purpose: Human docs for Gatus uptime monitoring on the NUC.
applies_to: Operators changing Gatus endpoints, alerts, or healthcheck setup.
entrypoint: Enable modules.services.gatus in host config; edit endpoints in default.nix.
verification: hey nuc switch, then check Gatus UI and healthchecks.io pings.
update_when: Endpoint URLs, conditions, alert providers, or install steps change.
---

# Gatus Uptime Monitoring

Automated service health monitoring for NUC using [Gatus](https://gatus.io/). Email notifications and Notion incident records are optional and disabled by default. The existing healthchecks.io timer watches Gatus and host availability separately.

## Installation

Enable in host config:

```nix
modules.services = {
  gatus = {
    enable = true;
    tailscaleService.enable = true;
    alerting.telegram = {
      enable = true;
      botTokenFile = config.age.secrets.telegram-bot-token.path;
      chatId = "8357890648";
    };
    healthcheck = {
      enable = true;
      pingUrl = "https://hc-ping.com/<uuid>";
    };
  };
};
```

Deploy:

```bash
hey nuc
```

## Access

- **Tailscale:** `https://gatus.cinnamon-rooster.ts.net`
- **Direct:** `http://<nuc-ip>:8084`

## One-Time Tailscale Setup

1. Go to [Tailscale admin → Services](https://login.tailscale.com/admin/services)
2. Create service: name `gatus`, endpoint `tcp:443`, tag `tag:server`
3. Deploy with `hey nuc`
4. Approve pending host in admin console

## Configuration Options

| Option                           | Default   | Description                                     |
| -------------------------------- | --------- | ----------------------------------------------- |
| `enable`                         | `false`   | Enable Gatus service                            |
| `port`                           | `8084`    | Web UI / API port                               |
| `tailscaleService.enable`        | `false`   | Expose via Tailscale serve                      |
| `tailscaleService.serviceName`   | `"gatus"` | Tailscale service name                          |
| `alerting.telegram.enable`       | `false`   | Send alerts via Telegram                        |
| `alerting.telegram.botTokenFile` | `""`      | Path to file with bot token                     |
| `alerting.telegram.chatId`       | `""`      | Telegram chat ID for alerts                     |
| `healthcheck.enable`             | `false`   | Enable healthchecks.io dead man's switch        |
| `healthcheck.pingUrl`            | `""`      | Full ping URL (e.g. `https://hc-ping.com/uuid`) |
| `healthcheck.interval`           | `"2min"`  | Ping interval                                   |

## Alerting

### Notion incidents and email notifications

Gatus posts debounced transitions to separate local Notion and email receivers.
Both use `incident-delivery.py`, with independent systemd services, SQLite files
and credentials. Neither path requires an agent or depends on the other path's
availability. The email receiver forwards to the Family Ops Cloudflare Worker;
it does not use SMTP or a Cloudflare account/admin API token.

Both routes are disabled by default. Before an approved rollout, provision a
database-scoped Notion connection, a dedicated Worker ingest token and separate
local ingest tokens through encrypted/runtime secrets. The Amp Notion connection
cannot authenticate a host daemon. The Worker route must be deployed and enabled
separately; configuring its future URL does not make it active. Publication,
deployment and real delivery tests are separate actions.

The routes default to `alerting.endpoints = [ "Home Assistant Runtime" ]`,
intersected with existing endpoint alert opt-ins. Cloudflare email currently
requires exactly that scope. Telegram's existing opt-in scope is unchanged.
Gatus triggers after three failed probes and resolves after two successful
probes. These thresholds do not suppress raw history or perform HA repairs.

#### Durable Gatus handoff

The carried Gatus patch in `overlays/gatus` enables `durable-delivery` only for
these state-only custom routes. Each has a distinct stable description,
`gatus-email` or `gatus-notion`. Gatus excludes provider overrides from alert
checksums, so identical descriptions and thresholds would merge route identities
on restart. Do not rename a route or change thresholds while it has pending work.

Gatus records debounced state and ordered transitions in its existing SQLite
file before attempting the receiver. Rejected failures and recoveries remain
pending across Gatus restarts, even if another incident occurs meanwhile.
Each route attempts one queued transition per probe. Acknowledged transitions
are removed only after their cursor is committed. A crash between receiver
acceptance and cursor persistence can replay the same head; local receivers
must remain idempotent. No event details, HA payloads or credentials enter this
producer queue. Telegram keeps upstream behavior.

Each producer route retains at most 1,000 transitions. SQLite uses FULL
synchronization once durable delivery starts. A full or unreadable/unwritable
producer outbox stops Gatus rather than silently discarding transitions.
Systemd retries the process; the existing external watchdog can detect loss of
Gatus availability. Preserve the database and reconcile the receiver before
retrying a full queue. Monitoring has a coverage gap while stopped; this is not
an unlimited outage buffer. Never delete producer state or change route identity
to bypass a pending or uncertain delivery. Removed configurations leave their
producer state in SQLite for reconciliation, not automatic replay or cleanup.

The following is a disabled configuration example, not secret provisioning:

```nix
modules.services.gatus.alerting = {
  endpoints = [ "Home Assistant Runtime" ];
  email = {
    enable = false;
    url = "https://mill-docs-agents.edmund-a-miller.workers.dev/api/monitoring/gatus-email";
    tokenFile = "/run/agenix/gatus-email-worker";
    ingestTokenFile = "/run/agenix/gatus-email-ingest";
  };
  notion = {
    enable = false;
    tokenFile = "/run/agenix/gatus-notion";
    ingestTokenFile = "/run/agenix/gatus-notion-ingest";
    dataSourceId = "<approved-data-source-id>";
    evidenceUrl = "https://<private-gatus-host>/";
  };
};
```

Both receivers accept only the configured endpoint label and state, authenticated
with their own local ingest token, and return HTTP 202 only after SQLite commits.
The Notion receiver binds to `127.0.0.1:8125`; email binds to `127.0.0.1:8126`.
Only the endpoint and `TRIGGERED`/`RESOLVED` state go to the Worker. Sender,
recipient and email template belong to Family Ops, not client-supplied fields.

#### Ordered Cloudflare email delivery

The email queue preserves every accepted transition in FIFO order. Repeated
states are ignored; orphan recovery sends nothing. Recovery and later incidents
cannot pass an unacknowledged failure, even after a receiver restart. The queue
retains at most 1,000 pending transitions plus 100 acknowledged rows. Full
capacity rejects new transitions with HTTP 503 rather than silently dropping
them. Accepted-state deduplication survives pruning and restarts.

The Worker has no durable acceptance queue. Only HTTP 200 with a documented
`accepted_by_provider`, `duplicate` or applicable `orphan_recovery` receipt
acknowledges the queue head. Generic 2xx or 202 responses do not. Provider
acceptance is not inbox delivery. A lost response retries the same head before
any recovery; the Worker owns state-based send deduplication.

HTTP 429 respects `Retry-After`, including a delay until UTC midnight under the
Worker's daily limit. Other retryable responses and network errors back off to
five minutes. Retry deadlines persist across restarts. HTTP 409 means delivery
is unknown. The local queue stops replaying that head and all later transitions
and remains unhealthy until approved operator reconciliation. Even a transient
in-flight conflict is conservatively blocked locally. Do not delete the queue,
clear the Worker's durable state, recreate a claim or send directly to bypass
an uncertain result. Neither side provides an exactly-once guarantee.

The payload has no source event ID or occurrence timestamp. A delayed trigger
after recovery cannot be distinguished from a fresh incident. Queued alerts can
also arrive after an outage has recovered. These receipt records are not exact
physical outage boundaries or an authoritative uptime ledger.

#### Notion incident records

Use a dedicated Notion data source with these properties:

| Property      | Type   | Purpose                                           |
| ------------- | ------ | ------------------------------------------------- |
| `Name`        | Title  | Configured Gatus group and endpoint name          |
| `Incident ID` | Text   | Receiver-generated correlation ID, keep unchanged |
| `Status`      | Select | `Open` or `Resolved`                              |
| `Detected`    | Date   | Time the receiver accepted the debounced failure  |
| `Recovered`   | Date   | Time the receiver accepted the debounced recovery |
| `Evidence`    | URL    | Credential-free link to the Gatus dashboard       |

Grant the Notion connection read, insert and update access only to that data
source. Ordinary Notion write notifications are silenced; database automations
can still run, so do not attach notification or agent automations implicitly.
Only the configured endpoint label, incident ID, receipt dates, status and
evidence URL are copied, not HA state, attributes, journal contents or tokens.
Source history stays in the Gatus and HA checker stores with existing retention.

Repeated failures reuse the current open incident; recovery updates its page.
The queue and page mapping survive receiver restarts. Local state retains at
most 1,000 open or pending incidents plus 100 delivered, resolved incidents.
Notion records are not automatically deleted. A full queue rejects new failures
with HTTP 503. Retries respect Notion's `Retry-After`, otherwise backing off to
five minutes.

A page-creation timeout can mean the write succeeded. The receiver uses a
returned committed page ID or queries `Incident ID` before continuing. If the
outcome cannot be established, it keeps querying and reports unhealthy instead
of creating a possible duplicate. Do not delete the queue or reset its attempted
creation flag. Inspect the committed page and obtain approval before repairing
a live mapping.

#### Delivery health and verification

Gatus checks `Notion Incident Delivery` and `Email Incident Delivery`. Delivery
errors, full capacity or an update pending five minutes make the relevant check
fail. These endpoints are dashboard-only, not emailed: the Worker permits HA
Runtime only and email must not recursively alert about its own failure. This
leaves a separate delivery-health notification gap; do not imply that a red
delivery check reaches the operator's inbox. Keep the external Healthchecks
watchdog for host/Gatus outages.

A receiver cannot backfill an outage Gatus never observed, including time while
Gatus or the NUC is down. Actual inbox delivery still requires separate live
acceptance. Run `hey check modules/services/gatus overlays/gatus`. The portable
check runs patched Gatus and the generated email service command against local
Notion and Worker fixtures. It covers partial receiver acceptance followed by a
Gatus restart, rejected recovery with another incident and restart before retry,
separate runtime secrets, ordered retries, rate limits, unknown delivery, privacy
and bounds. It contacts no live account. `pkg-check gatus` separately applies
the patch to fresh pinned upstream source and runs its focused Go tests.

#### One-shot synthetic acceptance before activation

After Family Ops provides its exact deployed revision, enabled binding/secret
readback, fresh idle-journal proof and an exclusive test window, the existing
Deploy NUC workflow can run `operation=gatus-email-acceptance` with the exact
published `expected_sha` and `email_test_family_revision`. This is a separately
approved live email test, not part of an ordinary deployment. Publish the test
operation while production email is still disabled; enable production email
only after controlled acceptance. The workflow keeps the exact-main CI guards
and deployment concurrency lock but does not activate NixOS for this operation.

The helper requires root on NUC, no installed production email receiver or
configured email route, no existing production email journal, healthy Gatus and HA
health endpoints, and the existing private credentials. A stable private snapshot
of Gatus's database must show no durable producer table, including retained routes
removed from current configuration. Existing state requires separate reconciliation;
the helper never resets or opens a live producer journal through SQLite.
It commits an exclusive intent under `/var/lib/gatus-email-acceptance/` before
the first external request.
It verifies unauthenticated 401 and authenticated invalid-state 400, then sends
one failure/recovery pair through an isolated loopback receiver and durable
FIFO. Each test transition requires a new `accepted_by_provider` receipt;
`duplicate` or `orphan_recovery` stops for reconciliation instead of advancing.
Ordinary production retry semantics remain unchanged. Production alert journals
and HA health are not modified. Any failed, ambiguous or 409 result stops the test.
A previous claim or journal always blocks rerunning, even after a crash; preserve it for operator reconciliation.
Do not delete it or invoke the helper again to bypass uncertainty.

The payload remains exactly endpoint/state. The fixed emails have no synthetic
flag or custom subject, so announce the test window and retain synthetic
provenance in its journal and evidence. Receiver acknowledgment alone does not
prove two provider acceptances or inbox receipt. Correlate both provider receipts
with Family Ops and verify the inbox separately before claiming acceptance.
This is synthetic delivery proof, not a genuine HA outage or seven-day stability.

#### Diagnostic after a blocked preflight

A failed acceptance intent remains a replay block. With separate approval and
fresh Family deployed SHA/version/settings/idle evidence, dispatch
`operation=gatus-email-diagnostic` with exact published `expected_sha`,
`email_test_family_revision` and `email_diagnostic_family_version`. This operation
never activates NixOS or resumes the acceptance pair. It requires the old intent
to contain only its initial record and refuses any retained acceptance FIFO,
including sidecars. It preserves that directory and all production journals.

The helper claims `/var/lib/gatus-email-diagnostic/claim.jsonl` exclusively before
requests. A prior diagnostic claim blocks reruns, including crashes. It sends
only unauthenticated and authenticated INVALID-state probes, stopping unless
401 unauthorized then400 invalid_transition are confirmed as exact error JSON.
It records phase, UTC timing, actual status, safe media type/error classification,
validated CF-Ray and local correlation IDs. It retains response metadata before
reading a body. Redirects are recorded with sanitized destinations and never
followed. Credentials, arbitrary bodies/headers, unknown host/path values,
queries and fragments are not logged. A network failure records only its fixed
category. No request body contains a test flag or valid transition.

Diagnostic success proves rejection paths only. It authorizes neither retrying
the preserved pair nor enabling production email. Retain its claim and evidence
for operator reconciliation; do not reset either claim to obtain another run.

### Telegram

Alerts on endpoint failure (3 consecutive failures) and recovery (2 consecutive successes). The bot token is managed via agenix and injected at runtime — never in the nix store.

### Dead Man's Switch (healthchecks.io)

A systemd timer pings the healthchecks.io URL every 2 minutes. If the NUC goes down or Gatus stops running, the ping stops and healthchecks.io sends an external alert.

**Setup:** Create a check at [healthchecks.io](https://healthchecks.io), set period to 2 minutes with 5 minute grace, copy the ping URL.

## Monitored Services

### Smart Home

- **Home Assistant** — `http://localhost:8123/manifest.json` (expects 200)
- **Homebridge** — `http://localhost:8581`
- **Matter Server** — `tcp://localhost:5580`

### Media

- **Jellyfin** — `http://localhost:8096/health`
- **Sonarr** — `http://localhost:8989/ping`
- **Radarr** — `http://localhost:7878/ping`
- **Prowlarr** — `http://localhost:9696/ping`
- **Audiobookshelf** — `http://localhost:13378/healthcheck` (conditional)
- **Music Assistant** — `http://localhost:8095` (conditional)

### Health

- **SparkyFitness** — `https://sparkyfitness.cinnamon-rooster.ts.net/` (conditional)

### Infrastructure

- **PostgreSQL** — `tcp://localhost:5432`
- **Tailscale** — `http://localhost:41112/healthz`
- **Hermes Web UI** — `http://127.0.0.1:8642` (conditional)
- **AgentsView** — `http://127.0.0.1:<agentsview-port>` (conditional)

## Adding Endpoints

Edit `default.nix` and add to the `endpoints` list:

```nix
{
  name = "My Service";
  group = "Category";
  url = "http://localhost:PORT/health";
  interval = "60s";
  conditions = [ "[STATUS] == 200" ];
}
```

Service-owned endpoints belong in the owning module's `registry.gatus`, with
`alerts = true` to opt in. Email and Notion also require a name match in
`alerting.endpoints`; they are not automatically attached to every endpoint.

For services that may not always be enabled:

```nix
++ optionals config.modules.services.myservice.enable [ { ... } ]
```

## Troubleshooting

**Service not starting:**

```bash
hey nuc-service gatus
hey nuc-logs gatus 50
```

**Config issues (check runtime config):**

```bash
ssh nuc "sudo test -s /run/gatus/config.yaml && sudo stat -c '%a %U' /run/gatus/config.yaml"
```

The runtime config contains credentials. Check its existence and permissions;
do not print it into a transcript or diagnostic log.

**Telegram alerts not working:**

```bash
# Verify secret is readable
ssh nuc "sudo test -s /run/agenix/telegram-bot-token"

# Check gatus logs for telegram errors
ssh nuc "journalctl -u gatus -n 50 --no-pager" | grep -i telegram
```

**Dead man's switch not pinging:**

```bash
hey nuc-service gatus-healthcheck-ping
ssh nuc "systemctl list-timers gatus-healthcheck-ping.timer"
```

**Dashboard unreachable via Tailscale:**

```bash
hey nuc-service gatus-tailscale-serve
ssh nuc "tailscale serve status"
```

**Endpoint showing down but service is running:**

Check the endpoint URL is correct and accessible from localhost on the NUC. Some services need time to start — Gatus retries automatically.

**Storage/data issues:**

```bash
ssh nuc "ls -la /var/lib/gatus/"
```

SQLite DB is managed by `DynamicUser` with `StateDirectory = "gatus"`.
