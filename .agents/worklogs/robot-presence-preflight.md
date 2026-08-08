# Worklog: robot-presence-preflight

Status: complete

## Objective

Replace robot cleaning's passive phone-age check with a fail-closed mobile-app
location preflight. Stop when regression coverage passes, the NUC deployment is
active, live refresh and fail-closed behavior are verified, and `origin/main`
contains the change.

## Decisions

- Record verified tracker events in per-phone `input_datetime` helpers so a Home
  Assistant restart cannot make restored tracker state appear freshly reported.
- Request location only when work is due: once from the scheduler and one noon
  retry after a failed response, never every five minutes.
- Require both phones to answer after the request, remain away for ten minutes,
  and stay verified within two hours before dispatch.
- Suppress stale and overdue cleaning alerts while vacation mode disables the
  scheduler.
- Preserve manual smoke-test authorization and all existing robot readiness,
  arrival-docking, and two-job guards.

## Evidence

- Live diagnosis: Monica's restored states shared the HA startup timestamp;
  opening each Companion app refreshed both trackers to `not_home`.
- Focused test: all HA automation assertions pass on the NUC; the four new
  regression assertions evaluate to `test = true` with no expected failures.
- NUC build: full system closure and Home Assistant `check_config` passed.
- NUC deployment: `/nix/store/firf2g6fx18z3w5p1ysnv7hf1qj5695n-nixos-system-nuc-26.11.20260714.18b9261`
  is current; Home Assistant is active with `Result=success`.
- Live refresh: Monica answered both silent requests; Edmund did not despite
  `Authorized Always` location permission. Both attempts timed out fail-closed,
  the script returned to `off`, and no robot dispatch was invoked.
- Same-day suppression: with today's recorded 09:55 dispatch, the deployed
  alert condition renders `False`.
- Test confidence audit: `PASS test-confidence`.

## Reviews

- Cross-model review not requested; current `AGENT_WORKFLOW.md` makes it optional.

## Feedback

- Passive `last_updated` freshness is not restart-safe for restored HA entities.
- The detached source checkout carried a stale workflow skill that contradicted
  `origin/main`; always re-read the declared source of truth after isolating work.

## Remaining work

- Land and prove the repository commits on `origin/main`.
- External follow-up: enable iOS Background App Refresh for Home Assistant on
  Edmund's phone and avoid force-quitting the app so silent pushes can wake it.

## Commits

- `9648e9b50` — `test(hass): specify robot presence preflight`
- `039a98ce3` — `fix(hass): verify phone presence before robot dispatch`
- `5ea4f16c1` — `fix(nix): hide Darwin-only options from NixOS` (prerequisite)
- `9e52f993d` — `test(hass): cover post-dispatch stale alert`
- `383f7d693` — `fix(hass): suppress stale alert after dispatch`
