# Worklog: ecobee-work-profile-safety

Status: complete

## Objective

Prevent either Ecobee from reverting to a 74 F Work target. Done when both native Work comfort settings read back at 72 F, every HA profile transition issues a real profile and exact-target write even with stale cached state, focused checks pass, and the live thermostats read back at 72 F.

## Decisions

- Test the public `script.apply_ecobee_profile` configuration seam already agreed with the user.
- Preserve native profiles as the normal policy, but always send the exact expected target because HomeKit selector and target caches can be stale.
- Keep the existing serialized per-thermostat retry and failure notification.
- Work locally without publishing; push authority was not granted.

## Evidence

- Live 2026-08-17 readback: Main Floor 74 F current / cached 72 F target / idle; Master Suite 75 F current / cached 72 F target / idle; manual override timer idle.
- Portal diagnosis found the active Work profile set to 74 F on both thermostats. Authenticated, device-specific reloads after the writes showed Work 72 F for thermostat IDs `416479340927` and `415567734077`.
- The expected-failure regression passed strictly before the fix; after removing the marker, `hey nuc-wt build` and the remote `ha-automation-assertions` check passed.
- `/run/current-system` is `/nix/store/bkrgr5xsjxzzqnzqypvvf83mdzd2wj6m-nixos-system-nuc-26.11.20260714.18b9261`; Home Assistant is active and its reload result is success.
- The active generated configuration unconditionally sequences clear hold, select profile, and exact `climate.set_temperature`, with one retry.
- A live policy run advanced both clear-hold timestamps to 2026-08-17 21:20:18 UTC. Both thermostats then read 72 F, `hvac_action: cooling`; Ecobee device cards independently showed 72 F targets.
- No `persistent_notification.ecobee_climate_transition_failed` entity exists after the run.
- `hey agent-audit-tests` and the full `hey agent-finish` landing manifest passed.

## Reviews

- Regression seam confirmed through the previously approved implementation plan.

## Feedback

- HomeKit cached targets can satisfy a target-only wait without proving the Ecobee accepted a current command.
- Browser Control 0.1.3 emitted repeated `Cannot respond. No request with id` page errors during a fresh Ecobee OAuth relay navigation. A short follow-up recovered the authenticated devices view. Creating the required project todo was attempted once and blocked by the repository's existing non-retryable `SYNC_CONFLICT`; no credentials or form values were recorded.
- `hey nuc-wt switch` activated and reloaded HA but exited 4 because unrelated 1Password rate limits and an existing `mill-docs` merge conflict failed other activation work.

## Remaining work

None.

## Commits

- `test(hass): capture cached Ecobee target drift`
- `fix(hass): enforce exact Ecobee profile targets`
- `docs(hass): record Work profile safety target`
