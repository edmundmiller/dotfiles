# Worklog: ha-reliable-temperature-control-20260815

Status: complete

## Objective

Make the Home Assistant climate control path hold the requested cooling target
on both Ecobee thermostats. Stop when the production script can set both
thermostats to 72 F, recorder/live readback stays at the intended target, the
NUC generation is deployed, and the landed revision equals `origin/main`.

## Decisions

- Preserve the unrelated edit in `config/agents/rules/15-agent-behavior.md`.
- Treat `script.activate_climate_manual_override` as the public feedback-loop
  seam because it is the documented explicit temperature-control path.
- Diagnose recorder contexts and automation traces before changing policy.
- Keep HA authoritative during Goodnight, but retain Ecobee as the fail-safe
  when core state is invalid or the front-door pause is active.
- Reconcile anonymous Ecobee target drift after five seconds. Only
  authenticated HA target changes become two-hour manual overrides because
  Ecobee schedule updates and Ecobee-app changes are otherwise indistinguishable.
- Re-evaluate 45-minute holds without pressing the Ecobee clear-hold buttons.

## Evidence

- Live repro on 2026-08-15: calling the explicit script with 72 F left both
  thermostats at 74 F while `input_boolean.goodnight` was on (`RED`).
- Recorder history shows repeated independent transitions back to 78 F after
  Home Assistant wrote bounded targets.
- HA trace `fad1e0da9b683e31e8c29c981aa58c5a` computed 72 F, set
  `policy_active=false`, canceled `timer.climate_policy_hold`, and pressed both
  clear-hold buttons solely because Goodnight was on.
- Runtime HA 2026.7.2 Ecobee code derives each hold duration from the
  thermostat `holdAction`; recorder timing is consistent with holds expiring
  at Ecobee schedule transitions.
- Strict expected-failure assertion evaluated `test=false` before the fix and
  `test=true` after it.
- `.#checks.x86_64-linux.ha-automation-assertions` passed on the NUC.
- `hey nuc-wt build` passed and built the HA config-check derivation and full
  NUC system closure.
- `hey agent-finish` passed the repository, agent-quality, instruction,
  confidence, and inventory gates.
- The first production reload exposed a second bug: the override timer restored
  as active while `input_number.climate_manual_override_target` reset from 72 F
  to its configured 74 F initial value.
- The restart-persistence assertion evaluated `test=false` with a strict
  expected-failure marker, then `test=true` after removing the helper's
  `initial` value so Home Assistant restores its recorded state.
- NUC generation 1332 (`/nix/store/jgwc8v3acfpl9cjrmqknbl7npgfbfba4-nixos-system-nuc-26.11.20260714.18b9261`)
  is current and `home-assistant.service` is active.
- Live production verification set both thermostats and the persisted helper to
  72 F, restarted Home Assistant, and read back 72 F on both with the override
  still active.
- Pressing both Ecobee clear-hold buttons produced anonymous 74 F schedule
  drift. The deployed five-second trigger restored both thermostats to 72 F at
  the six-second readback and they remained 72 F through 20 seconds.

## Reviews

No cross-model review requested.

## Feedback

None yet.

## Remaining work

None.

## Commits

- `c714c3a6d` test(hass): capture unreliable Ecobee target control
- `ad2b1572b` fix(hass): keep Ecobee targets authoritative
- `d3c965d1c` docs(agent): record Ecobee reliability work
- `4280c86e1` test(hass): capture climate override restart loss
- `67f5356c4` fix(hass): persist manual climate target
