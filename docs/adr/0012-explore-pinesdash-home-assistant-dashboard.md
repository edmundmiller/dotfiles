---
purpose: Record Pinesdash as a reference for exploring a Home Assistant wall dashboard.
applies_to: Future Home Assistant dashboard design and tablet UI experiments.
entrypoint: Compare the linked Pinesdash walkthrough with existing HA dashboards before prototyping.
verification: Evaluate a fixture-backed prototype and compare usability and maintenance with Lovelace.
update_when: The exploration selects an approach, rules it out, or establishes deployment requirements.
---

# ADR 0012: Explore a Pinesdash-inspired Home Assistant dashboard

## Status

Proposed exploration. No implementation or deployment decision.

## Date

2026-10-08

## Context

[Pinesdash](https://pinesdash.share.warpspire.com/) demonstrates a wall-tablet
dashboard for lights, climate, energy, air quality, and security. Its walkthrough
describes a framework-free TypeScript/Vite app served as static files by Home
Assistant, communicating directly through HA's websocket API without a separate
application server. The captures use recorded fixtures in mock mode, not a live
house. These are the author's reported design choices, not behavior verified
against source code or our installation.

Our Home Assistant infrastructure lives in `modules/services/hass/`. A custom
dashboard could provide a focused household interface, but would also make us
responsible for authentication, reconnect behavior, state reconciliation, and
compatibility with HA updates. Existing Lovelace dashboards remain an alternative
and a fallback.

## Exploration

Keep Pinesdash as a design and architecture reference. Compare adapting existing
HA dashboards with building a small custom frontend before choosing either.
Source availability and reuse licensing have not been established by this
walkthrough; this proposal does not assume Pinesdash can be installed or copied.

Ideas worth testing:

- Let idle controls recede and highlight active or unusual states. Define what
  counts as unusual for our devices rather than copying the reference house.
- Use tap-to-toggle controls with a hold-to-adjust sheet, while checking that
  adjustment controls remain discoverable and accessible without a long press.
- Require confirmation for consequential actions. Pinesdash uses a second tap
  within four seconds; assess that interaction separately for each action.
- Keep controls owned by another controller or automation read-only, with an
  explanation of which system owns them.
- Reconcile optimistic updates with HA state. Pinesdash uses a six-second
  timeout; test rejected commands and disconnects so the UI never presents an
  unconfirmed result as authoritative.
- Use fixture-backed mock mode to review normal, unavailable, and failure states
  without sending service calls to real devices.

## Questions before adoption

- Which household tasks and target screen sizes justify a separate interface?
  The reference's fixed 1000×600 stage and hardware are not requirements here.
- Can Lovelace deliver those interactions with less ongoing maintenance?
- Which entities and recorder statistics are actually available, and what should
  the UI show when readings are stale or unavailable?
- Can a dedicated non-admin HA session provide the required access? Keep tokens
  out of static assets, Git, and Nix output; verify session recovery and the
  account's actual permissions rather than treating hidden controls as security.
- If a custom app wins, where should its source live, and how should reproducible
  builds, static-file delivery, cache invalidation, and rollback fit our Nix-owned
  deployment? Do not copy the reference's rsync release procedure by default.

## Revisit criteria

Revisit this ADR after a small fixture-backed comparison demonstrates the most
important household tasks on the intended device, including stale data,
connection loss, rejected actions, and confirmation behavior. Record whether the
usability benefit warrants maintaining a custom frontend or whether existing HA
dashboards suffice.

This ADR records an idea to explore. It does not authorize a prototype, live
service calls, account changes, dashboard replacement, or host deployment.

## Source

- [Pinesdash walkthrough](https://pinesdash.share.warpspire.com/), accessed
  2026-10-08.
