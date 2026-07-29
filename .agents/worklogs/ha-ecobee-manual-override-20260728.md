# Worklog: ha-ecobee-manual-override-20260728

Status: complete

## Objective

Stop Home Assistant from fighting a deliberate Ecobee/thermostat target change. A manual target change must start a bounded two-hour comfort override, apply that target to both thermostats, and automatically resume the normal climate policy afterward.

## Decisions

- Keep Home Assistant's awake climate policy and Ecobee's fallback schedule.
- Treat an external target change while HA's hold watchdog is active as a manual override.
- Provide an explicit override target and script for a predictable Home Assistant control path.
- Ignore grid and humidity adjustments during the bounded manual override.

## Evidence

- Live recorder history showed repeated manual/schedule transitions to 74 F followed by `automation.climate_policy` calls restoring 71.5 F.
- At 18:45 CDT, master-suite humidity was 62 percent; the policy restarted a 45-minute hold and both thermostat entities reported a 71 F target.
- The red assertion run failed exactly 4/117 manual-override requirements. The expected-failure test commit kept the suite green; the implementation then passed all 117 assertions.
- `hey nuc-wt build`, the explicit remote `ha-automation-assertions` build, `hey nuc dry-activate`, and `hey nuc` passed. NUC generation 1238 is active.
- Live automatic detection at 18:59 CDT changed one thermostat to 73 F; HA propagated 73 F to both, updated the override target, and restarted the two-hour override.
- Live expiry at 19:00 CDT returned both targets to the normal 71 F humidity policy and triggered the resume automation.
- The final dog-comfort override restored both thermostats to 74 F through 21:00 CDT. The 19:00 periodic policy run did not cancel the active override.
- Local `darwin-rebuild switch --flake .` passed.
- `hey check` passed Darwin evaluation, lock sync, tmux, package harness, package policy, and ast-grep tests. Its formatter/pre-commit steps failed before checking files because the current repository has neither `prek.toml` nor `.pre-commit-config.yaml`.
- `hey agent-audit-tests` passed. Two `hey agent-finish` attempts passed worklog, repo-quality, test-confidence, inventory, and all ordinary Darwin groups, but its unrelated `test_start_creates_an_isolated_jj_workspace_and_receipt` failed while running `jj git init --colocate` inside the installed Nix-store test source; the same command succeeds directly in a fresh local temp repository.

## Reviews

- Plan review attempted with `hey agent-review plan --active-model-family openai`; ACP session creation exited 1 with `Authentication required`.
- Landing review attempted with `hey agent-review landing --active-model-family openai`; ACP session creation exited 1 with `Authentication required`.

## Feedback

- The shared Git hook and `hey check` still require `.pre-commit-config.yaml`, but the current default branch removed every prek config. Commits require `PREK_ALLOW_NO_CONFIG=1`, and the wrapper reports two false failures.

## Remaining work

- None.

## Commits

- `bdbeb69` — `test(hass): specify bounded manual climate override`
- `2cd8248e7` — `fix(hass): respect bounded manual climate targets`
- Worklog closure commit (this commit).
