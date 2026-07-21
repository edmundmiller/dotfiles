---
purpose: Record why Buzz is promising but not yet part of the self-hosted agent stack.
applies_to: Decisions about deploying Buzz or replacing Hermes messaging surfaces.
entrypoint: Reassess the revisit criteria before proposing a deployment.
verification: Compare current Buzz releases and live NUC capacity with this evidence snapshot.
update_when: Buzz reaches the revisit criteria or a bounded pilot produces new evidence.
---

# ADR 0009: Defer Buzz as a core self-hosted agent workspace

## Status

Accepted — watchlist, not approved for permanent deployment

## Date

2026-07-21

## Context

[Buzz](https://buzz.xyz/) is Block's Apache-2.0 workspace for humans and AI
agents. Humans, agents, workflows, and Git activity use signed Nostr events in
one relay-backed audit trail. Its agent-facing CLI and ACP harness are designed
to connect tools including Codex, Claude Code, and Goose.

This direction fits the desired collaboration model well: agents have their own
identities and channel memberships, project history stays with the discussion,
and patches, review, workflow evidence, and approvals can share one searchable
record. Strategically, Buzz is a stronger fit than treating agents as bots
scattered across unrelated messaging and automation systems.

The current stack already runs multiple Hermes profiles on the NUC and uses
Telegram and Discord as user-facing delivery surfaces. Buzz would currently add
another workspace and state system rather than replace a proven boundary.

## Decision

Do not deploy Buzz as permanent infrastructure or migrate Hermes conversations
to it yet.

Keep Buzz on the watchlist. Reassess it as a possible collaborative front end
while Hermes remains the agent runtime, rather than assuming Buzz must replace
Hermes.

Current assessment:

- Strategic fit: **8/10**
- Operational fit: **4/10**
- Recommended action: **defer; consider only a disposable pilot**

## Reasons

### The product boundary is still moving

Buzz is explicitly pre-1.0. Its security policy fully supports only the latest
`main`, and the single-node Compose deployment defaults to
`ghcr.io/block/buzz:main`. The deployment guide recommends pinning a commit or
stable release tag for production. Mobile clients, push notifications, and some
workflow approval integration are not all in the project's "works today"
column.

Those gaps matter because Telegram and Discord already provide reliable mobile
delivery. Buzz does not yet justify displacing them.

### Self-hosting adds several stateful dependencies

The production Compose bundle runs the Buzz relay plus PostgreSQL, Redis,
MinIO, and a Git data volume. Operating it safely requires stable identity and
application secrets, TLS, coordinated backups, upgrades, migrations, and a
tested restore path across those state stores. It is not a single lightweight
service.

Buzz's channel membership model is intentionally simple: a human or agent that
belongs to a channel can read and write there. That is elegant, but coarse for
the differently privileged, secrets-bearing personal agents already deployed.

### The NUC can host it, but capacity is not the deciding problem

The live NUC snapshot on 2026-07-21 showed:

- 31 GiB RAM total, 21 GiB used, and 9.4 GiB available;
- no swap;
- 440 GiB filesystem space available;
- Docker and PostgreSQL already active.

Buzz's Helm defaults allow up to 2 GiB for the relay before PostgreSQL, Redis,
MinIO, and normal workload growth. The machine can probably run a small
instance, but doing so would consume failure and maintenance headroom in an
already substantial service stack. Recheck live capacity rather than treating
this snapshot as permanent:

```bash
ssh nuc \
  'free -h; df -h / /var/lib; systemctl is-active docker postgresql redis minio'
```

## Revisit criteria

Reopen this decision when most of the following are true:

- Mobile clients and push notifications are in the documented "works today"
  set and are usable for normal personal delivery.
- The Compose path defaults to, or clearly supports, a stable release image
  rather than asking early adopters to track `main`.
- Backup and restore procedures cover PostgreSQL, Redis, object storage, Git
  state, relay identity, and application secrets, with a practical restore
  drill.
- Buzz demonstrates a stable authorization boundary suitable for agents with
  different privileges, or channel membership is proven sufficient for the
  intended deployment.
- A compatibility spike proves that `hermes-acp`, or another supported Hermes
  adapter, can participate through Buzz's ACP harness without duplicating agent
  runtime state.

The decisive use case is a real shared project room where multiple humans and
agents need discussion, Git changes, CI evidence, review, and approvals in one
durable record. A prettier dashboard for existing personal agents is not enough.

## Pilot boundary

A future pilot is allowed without reopening the permanent-deployment decision
if it remains reversible:

- Tailscale-only access; no public ingress.
- One disposable project and one low-privilege agent.
- Isolated databases, object storage, and volumes; do not reuse production
  Hermes state or existing PostgreSQL databases.
- No sensitive repositories, durable secrets, or conversation migration.
- A fixed evaluation window followed by either a documented restore/deletion
  exercise or removal of the pilot.

The pilot must answer whether Buzz materially improves collaborative work and
whether Hermes-to-Buzz ACP integration is viable. Installation success alone
is not acceptance evidence.

## Consequences

Positive:

- Avoids adding a premature stateful platform to the NUC.
- Preserves reliable Telegram and Discord delivery while Buzz's mobile path
  matures.
- Keeps the strategically valuable idea visible with objective revisit
  triggers.
- Allows a safe integration experiment without implying production adoption.

Tradeoffs:

- The current agent activity trail remains split across Hermes state,
  messaging surfaces, repositories, and operational artifacts.
- Delaying adoption may postpone useful experience with Buzz's identity and
  event model.
- Reassessment requires checking upstream behavior rather than relying on this
  dated snapshot.

## Sources

Accessed 2026-07-21:

- [Buzz repository and capability status](https://github.com/block/buzz)
- [Single-node Docker Compose deployment](https://github.com/block/buzz/tree/main/deploy/compose)
- [Helm deployment defaults](https://github.com/block/buzz/tree/main/deploy/charts/buzz)
- [Buzz security policy](https://github.com/block/buzz/blob/main/SECURITY.md)
