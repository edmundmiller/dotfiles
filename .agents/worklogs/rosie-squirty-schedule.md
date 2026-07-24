# Worklog: rosie-squirty-schedule

Status: active

## Objective

Replace departure-triggered Roomba starts with disabled-by-default, interval-based
mapped-room dispatch. Stop after source, tests, documentation, deployment gating,
and live evidence are recorded; do not activate without fresh Monica phone
presence and verified map identifiers.

## Decisions

- Work in an isolated branch from `origin/main`; the user's active checkout has
  unrelated unresolved Herdr conflicts.
- Public test seam: evaluated Home Assistant configuration.
- Runtime seams: Home Assistant entity state and recorder mission transitions.
- Fail closed for stale presence, unknown map identifiers, or robot maintenance.

## Evidence

- Active checkout contained unrelated unresolved Herdr conflicts before edits.
- Live recorder showed Monica's iPhone tracker stale and `person.moni` sourced
  from the always-home MacBook.
- Live robots: Rosie i755020 and Squirty m611320.
- Regression assertions first failed with ten cleaning-contract failures.
- NUC build passed, including Home Assistant's generated-config validation:
  `/nix/store/q534f6l17ywq5ml142xsknxmp8yyg7hx-nixos-system-nuc-26.11.20260714.18b9261`.
- Focused HA assertion evaluation returned `[]`.
- `hey agent-audit-tests` returned `PASS test-confidence`.
- `hey agent-finish` passed applicable repository quality checks.
- Live recorder confirms expected readiness entities; Rosie is currently blocked
  by a full bin. Robot entity attributes do not expose saved-map IDs.

## Reviews

- Plan source: user-approved Rosie + Squirty Adaptive Cleaning Schedule.
- Automated plan review was unavailable because the configured reviewer returned
  `Authentication required`; no retry was made.

## Feedback

None.

## Remaining work

- Review, commit, land, deploy disabled configuration, and record live boundaries.

## Commits

None.
