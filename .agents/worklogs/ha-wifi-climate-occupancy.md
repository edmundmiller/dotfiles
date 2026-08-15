# Worklog: ha-wifi-climate-occupancy

Status: complete

## Objective

Make awake climate occupancy true when either person's GPS is home or either
phone reports the home SSID, wait two hours after all four signals are away,
use 76 F for ordinary away cooling, and retain 78 F for vacation. Stop after
focused assertions and the NUC build exercise the generated automation, then
deploy, verify, and publish when explicitly authorized.

## Decisions

- Treat `Aviato` as positive occupancy evidence for climate only. A stale home
  SSID may delay energy savings, which is safer than false-away cooling.
- Use 76 F as the requested lower dog-safe away target; keep vacation at 78 F.
- Keep GPS as the fallback and trigger re-evaluation from both GPS and SSID
  transitions.
- Cross-model review is optional in `AGENT_WORKFLOW.md` and was not requested.
  The user's numbered requirements are the plan gate.

## Evidence

- Live HA readback: Edmund's iPhone reported `Aviato` while GPS reported
  `Parking Lot`; current entities are provided by the `mobile_app` integration.
- RED: focused HA assertions failed 3/138 for the old one-hour, person-only,
  shared-78 behavior.
- GREEN: focused HA assertions passed after the implementation.
- `hey nuc-wt build` passed and exercised generated `configuration.yaml`,
  `hass-check-config`, the Home Assistant unit, and the full NUC system build.
- Narrow Nix evaluation read back both SSID triggers, two-hour GPS and SSID
  timers, ordinary-away target 76, and vacation target 78.
- Replayed the exact patch onto a clean detached `origin/main` worktree at
  `f37c6b35d`; its stable patch ID matches the tested source patch.
- The fresh worktree passed the focused HA assertions, `hey nuc-wt build`, and
  `hey nuc-wt dry-activate`, which reported only a Home Assistant reload.
- Switched the NUC from generation `5qk54wqg` to `d5jppiy8`. Home Assistant is
  active, its HTTP API is healthy, and it logged no warnings or errors after
  reload.
- Live installed configuration contains both `Aviato` sensors, the 7,200-second
  delay, ordinary-away 76 F, and vacation 78 F. A live policy trace computed
  72 F from Edmund's current `home`/`Aviato` evidence while Goodnight kept the
  HA hold idle.
- The overall switch command returned nonzero because
  `home-manager-emiller.service` again encountered its pre-existing Herdr
  `server_not_running` activation failure, also recorded on August 10, 11, and 13. A bounded transient Herdr server allowed Home Manager to finish; Home
  Manager is active and the transient server is stopped. The climate service
  and generation switch completed successfully.
- NUC activation also exercised the existing Obsidian corruption guard. It
  found an unresolved marker in
  `07_Metadata/Reports/cloudflare-flue-morning-check.md` and correctly kept
  Obsidian Sync stopped; the guard was not bypassed.

## Reviews

- Plan: user approved two-hour delay, lower ordinary-away cooling, and higher
  vacation cooling; 76 F is the explicit implementation assumption announced
  before editing.

## Feedback

None.

## Remaining work

None within this task.

## Parked

- The recurring Home Manager/Herdr activation failure is outside this climate
  change and remains a separate repair.
- The Obsidian conflict marker and mill-docs unresolved conflict are pre-existing
  safety/maintenance items and were not modified by this climate task.

## Commits

See the landed Git history for the task revision.
