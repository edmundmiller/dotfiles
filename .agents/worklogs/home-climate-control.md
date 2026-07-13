# Worklog: home-climate-control

Status: active

## Objective

Make Home Assistant the explicit thermostat policy engine with safe Ecobee fallback, fresh ERCOT grid signals, bounded holds, door-open pause behavior, structural tests, remote deployment, and live verification.

## Decisions

- Ecobee/HomeKit remains the equipment controller; Home Assistant owns awake occupied/away/vacation targets.
- Sleep and invalid core state clear holds so the Ecobee schedule is the fail-safe.
- ERCOT uses the current unauthenticated JSON endpoint with timestamp freshness checks; stale data is ignored.
- Smart Meter Texas and Electricity Maps remain config-flow integrations. Enable their components and document prerequisites; never fake credentials in Nix.
- Use the existing front-door contact sensor for Pause When Open. Every pause has a close-triggered policy reapply.

## Evidence

- Live discovery: Ecobee connected through HomeKit Controller; clear-hold buttons available; no cloud `ecobee.*` actions.
- ERCOT endpoint: `daily-prc.json` exposes `lastUpdated` and current condition.
- Remote HA evaluation assertions passed after first proving the new assertions failed.
- `hey nuc-wt build`, `hey nuc dry-activate`, and `hey nuc` passed.
- Live HA verified the policy script, watchdog timer, fresh ERCOT sensor, sleep fallback, and restored Ecobee schedule after a temporary hold.
- `darwin-rebuild switch --flake .` and `hey check` passed locally.

## Reviews

- Approved direction established in conversation: Home Assistant policy ownership with Texas grid and energy inputs.
- Automated plan gate attempted with `hey agent-review plan --active-model-family openai`; ACP session creation exited 1 with `Authentication required`.
- OpenCode ACP review found missing clear-hold, door pause, ERCOT, bounded-hold, and sleep behavior; all findings were implemented and verified.
- Code-simplifier fallback could not run because the configured OpenRouter account lacked credits.
- Landing review retried with `hey agent-review landing --active-model-family openai`; ACP session creation again exited 1 with `Authentication required`. `hey agent-finish` passed immediately before the retry.

## Feedback

- HA action-level variables are evaluated independently; templates must not depend on sibling variables declared in the same action.

## Remaining work

- Run landing gates, commit, pull/rebase, push, and verify upstream.
- Complete Smart Meter Texas and Electricity Maps config flows when credentials/API key are available.

## Commits

None.
