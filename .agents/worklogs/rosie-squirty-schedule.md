# Worklog: rosie-squirty-schedule

Status: deployed-disabled

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
- Review regressions first failed on command-error handling, numeric mission
  counters, direct-call guards, and bounded docking. The repaired assertions
  return `[]`; final NUC build:
  `/nix/store/n7ydvlhvhl30p6rgff7f2qfi0lzvshgb-nixos-system-nuc-26.11.20260714.18b9261`.
- Live recorder confirms expected readiness entities; Rosie is currently blocked
  by a full bin. Robot entity attributes do not expose saved-map IDs.
- Dry activation and deployment succeeded. `/run/current-system` is
  `/nix/store/8frgwib79p8ydgrn3pbkjm3prlf1ia8j-nixos-system-nuc-26.11.20260714.18b9261`.
- Initial 2026-07-23 live state: scheduler and arrival automations on;
  scheduler-enabled and two-job helpers off; legacy departure automation absent.
- All seven map/version/region helpers are `unknown`; no robot command ran.

## Reviews

- Plan source: user-approved Rosie + Squirty Adaptive Cleaning Schedule.
- Automated plan review was unavailable because the configured reviewer returned
  `Authentication required`; no retry was made.
- Independent standards and specification reviews found command exceptions
  aborting notifications, unavailable counters permitting false success, direct
  calls bypassing guards, a 92-minute watchdog, and premature chaining before
  docking. Re-review also found unvalidated job IDs and ambiguous direct job
  authorization. All were repaired with regression assertions.
- Final standards and specification re-reviews reported no findings.

## Feedback

None.

## Rollout gates

- Prove Monica and Edmund home → away → home transitions.
- Populate and verify saved-map/version/region helpers.
- Empty Rosie's bin, then run one controlled mapped-room smoke test per robot.
- Review one week of recorder history on July 31, 2026.

## Commits

- `8cf727face` — adaptive cleaning scheduler and regression/spec assertions.
- `86fdd60e2a` — command, counter, direct-call, watchdog, docking, and job-ID hardening.
- `572e7a22` in mill-docs — canonical household cleaning policy.
