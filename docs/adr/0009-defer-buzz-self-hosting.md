---
purpose: Record why Buzz relay self-hosting remains deferred and bound the hosted NUC runtimes.
applies_to: Decisions about self-hosting Buzz or operating NUC Buzz agent runtimes.
entrypoint: Inspect `buzz-hermes-*`, `mill-docs-coding-agent.timer`, and the MillDocs Buzz runbook.
verification: Verify live runtimes and compare current Buzz releases with the self-hosting criteria.
update_when: The hosted runtime boundary, Buzz deployment model, or self-hosting criteria change.
---

# ADR 0009: Defer Buzz as a core self-hosted agent workspace

## Status

Accepted — defer relay self-hosting; allow bounded hosted-relay runtimes

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

Do not self-host the Buzz relay or replace existing Hermes delivery surfaces
with Buzz.

Expose the configured NUC Hermes profiles to the hosted Millers community as
separate, low-privilege agent runtimes. MillDocs Buzz is owned by its dedicated
Cloudflare Worker; the NUC only executes its typed Linear coding queue. This is
a client integration, not a Buzz infrastructure deployment. Hermes remains the
primary agent runtime for the other profiles.

Current assessment:

- Strategic fit: **8/10**
- Self-hosted operational fit: **4/10**
- Action: **operate bounded hosted runtimes; defer relay self-hosting**

## Hosted runtime architecture

```text
                                  ┌─> Hermes ACP profile A ─> declared repos
Buzz community ─WSS─> buzz-acp ──┼─> Hermes ACP profile B ─> declared repos
                  one identity    └─> Hermes ACP profile N ─> declared repos
                  per profile

Buzz community ─HTTP─> dedicated Flue 2 Worker ─> Linear queue ─> NUC executor
```

`hosts/nuc/default.nix` owns the generated `buzz-hermes-<profile>.service`
units and the MillDocs coding-agent timer. Each Hermes unit uses the profile's
materialized home, package, environment, and declared host mounts. Each has a
dedicated Nostr identity from agenix, one channel matching its repository
boundary, owner-only mention routing, lazy ACP startup, no inbound port, and no
host Docker or Podman socket.

Project ownership follows the canonical agents workspace: Finn owns the
`finances` checkout and forum; Anne and Betty share `mill-docs`; Amos Burton,
Orchestrator, and Scintillate use `general`.

The Cloudflare MillDocs Worker keeps its exact author allowlist. Add Moni only after her
64-character relay pubkey is known and her identity belongs to the community.

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
- Several weeks of live use show that per-profile Hermes ACP processes coexist
  safely with cron state, provider credentials, and repository writes.

The decisive use case is a real shared project room where multiple humans and
agents need discussion, Git changes, CI evidence, review, and approvals in one
durable record. A prettier dashboard for existing personal agents is not enough.

## Hosted runtime boundary

The approved runtimes remain narrow:

- Use the hosted relay; do not deploy Buzz databases or object storage.
- Use one dedicated Buzz identity per Hermes profile.
- Keep every private key and owner attestation in a separate agenix secret.
- Require explicit owner mentions and disable heartbeat by default.
- Derive repository access from the profile's existing host mounts.
- Keep the Mill Docs Codex worker's project-specific sandbox and allowlist.

Acceptance requires a live Hermes reply, a non-mention drop, restart recovery,
and profile-specific filesystem boundary probes. Installation success alone is
not evidence. The Mill Docs two-person allowlist remains incomplete until Moni
joins and the member-negative probe passes.

## Consequences

Positive:

- Avoids adding a premature stateful platform to the NUC.
- Preserves reliable Telegram and Discord delivery while Buzz's mobile path
  matures.
- Makes existing Hermes profiles available in Buzz without widening their
  repository access.
- Keeps relay self-hosting gated by objective revisit criteria.

Tradeoffs:

- Agent activity remains split across Hermes state,
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
