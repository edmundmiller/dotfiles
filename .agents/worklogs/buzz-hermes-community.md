# Worklog: buzz-hermes-community

Status: complete

## Objective

Run each configured NUC Hermes profile as a separate agent runtime in
`wss://millers.communities.buzz.xyz` through `buzz-acp -> hermes acp`.
Each runtime must inherit only its profile-owned workspace/repository access,
respond only to the owner by default, expose no inbound listener, survive
restart, and remain declarative.

Stopping condition: focused Nix tests pass; the NUC build, dry activation, and
switch succeed; every configured Buzz/Hermes service is active with its own
identity; Buzz shows the `mill-docs` and `finances` projects plus the
agent-community pairs; and one live mention produces a Hermes reply that proves
the expected repository boundary.

## Decisions

- Keep reusable Hermes profile rendering in `agents-workspace`; keep Buzz
  identity secrets, relay routing, service enablement, and host mounts here.
- Model one service and one Nostr identity per Hermes profile. Buzz documents
  separate keys for separate agents; a shared identity would collapse audit
  and mention boundaries.
- Reuse each canonical profile's materialized Hermes home and declared host
  mounts. Do not create a second repository allowlist.
- Start with owner-only mentions and no heartbeat.

## Evidence

- Local Hermes v0.17.0: `hermes acp --check` passed.
- NUC Hermes v0.18.2: `hermes acp --check` passed for Amos Burton, Anne,
  Betty, Orchestrator, and Scintillate.
- Remote `acpx` exact-reply sessions passed through `hermes acp` for all five
  profiles.
- Existing `buzz-mill-docs-codex.service` is active, has zero restarts, and
  connects outbound without a listener.
- Red: the focused NUC check failed because `buzz-hermes-anne.service` did not
  exist.
- Green: `hey nuc-wt build` and
  `nuc-buzz-hermes-community-runtime` passed with temporary mock identity files.
  Current placeholder files are deliberately invalid age payloads and must be
  replaced by five real encrypted identity sources before activation.
- Audit caught and fixed container-to-host path translation: all environment
  paths now resolve to declared host mounts, including profile-specific
  `CODEX_HOME`, `TN_VAULT_PATH`, and `WIKI_PATH`. Fresh NUC eval confirms the
  exact translated paths for all five profiles.
- Generated-unit inspection caught host Docker and Podman sockets outside the
  canonical profile mount boundary; every Buzz/Hermes unit now masks both.
- Fresh `hey nuc-wt build` and the focused Nix check pass after the path fix.
- `systemd-analyze verify` passes for all five generated unit files; reported
  warnings belong to unrelated live Tailscale units.
- The owner published `mill-docs` and `finances` as NIP-34 repository
  announcements backed by the Millers Buzz Git service. Fresh relay reads,
  complete ref pushes, and authenticated clean clones match the source main
  commits.
- Five distinct owner-attested agent profiles are live. Each encrypted identity
  decrypts locally, appears as a bot in its least-privilege channel, and can
  read that channel with its own credentials.
- `hey nuc-wt switch` deployed the current worktree generation. All five
  `buzz-hermes-*` units are active with zero restarts, authenticated to the
  Millers relay, subscribed to exactly one assigned channel, and expose no
  listener.
- A natural owner mention in `finances` started `hermes acp`; Amos Burton
  verified the finances Git workspace and absence of a Mill Docs workspace,
  then returned the exact acceptance token. A non-mention produced no agent
  reply.
- An explicit restart recovered all five relay connections and channel
  subscriptions with zero automatic restarts.
- `nixfmt --check` and `git diff --check` pass for the current changes.

## Reviews

- Plan review: unavailable. The heterogeneous reviewer reached ACP
  `session/new` and returned `RUNTIME: Authentication required`.
- Landing review: `sem diff --staged` confirmed the change is limited to the
  NUC Buzz runtime, its tests, encrypted identities, and canonical docs.

## Feedback

None.

## Remaining work

None.

## Commits

- `9267732e1` — `feat(nuc): run Hermes profiles in Buzz community`
