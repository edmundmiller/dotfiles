# Worklog: busy-bar-bedtime-widget

Status: active

## Objective

Deploy a Home Assistant-managed 72×16 BUSY Bar bedtime countdown with five six-minute checkpoints during the final 30 minutes before the canonical alarm-relative in-bed target.

Done when the Nix assertions pass, the NUC configuration deploys healthy, a Home Assistant test event renders the expected countdown/checkpoints through the BUSY Bar Canvas API, an out-of-window event clears only `home_assistant_bedtime`, and `light.busy_bar` remains unchanged.

## Decisions

- Keep Matter `light.busy_bar` for BUSY/custom activity only; use namespaced LAN HTTP Canvas calls for drawing.
- Follow the approved plan in `local://busy-bar-bedtime-widget-plan.md` exactly.
- Use priority 50 and 75-second element timeouts so firmware priority-90 activity wins and stale content expires.

## Evidence

- Host before host-specific action: `MacTraitor-Pro.local`, Darwin arm64.
- Current checkout is a Herdr Git worktree; `jj root --ignore-working-copy` reported no jj repository.
- BUSY Bar firmware `1.1.1` answered its LAN API at `http://192.168.1.207`; USB status independently reported the same DHCP address.
- Nix parsing, `hey nuc-wt build`, and `checks.x86_64-linux.ha-automation-assertions` passed.
- `hey nuc dry-activate` passed. After rebasing current `origin/main`, `hey nuc-wt switch` activated `/nix/store/gcqb54x2hyd626s6dahbfwch2k1hw19y-nixos-system-nuc-26.05.20260801.684a460`.
- The deployed Home Assistant configuration contains the automation and both REST commands. Home Assistant is active, the automation is `on`, and both REST services are registered.
- A `busy_bar_bedtime_test_tick` with a target 15 minutes ahead rendered `14:56`. Pixel measurement found five checkpoint rectangles: two cyan and three dim gray.
- A second test tick one second after its target removed the bedtime widget and restored the prior clock display, proving the delete remained application-scoped.
- Before and after both Canvas tests, `light.busy_bar` remained `off` with `supported_color_modes: ["onoff"]` and `supported_features: 0`.
- Final focused validation passed: task-file formatting, `hey nuc-wt build`, `checks.x86_64-linux.ha-automation-assertions`, `hey agent-audit-tests`, and `hey agent-finish`.

## Reviews

- Plan: approved by the user. `hey agent-review plan --active-model-family openai` could not run because the review provider returned `Authentication required`.
- Landing: `hey agent-review landing --active-model-family openai` could not run because the review provider returned `Authentication required`. Manual focused diff review found no unresolved issue.

## Feedback

- The first deploy source became stale while `origin/main` advanced. Rebase conflicts were limited to pre-existing Herdr documentation commits and were resolved by retaining both upstream qmd seeding and the branch's OMP/Hunk behavior. A fresh build and switch then activated the intended configuration.
- The silent-failure specialist could not start because its provider had no selected model; manual review remains part of landing cleanup.

## Remaining work

Commit, rebase, publish, tag, and verify upstream equality.

## Commits

Pending.
