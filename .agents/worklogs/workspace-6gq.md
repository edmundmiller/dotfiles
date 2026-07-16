# Worklog: workspace-6gq

Status: blocked

## Objective

Make the NUC Radar cron-tick service expose the canonical `rtk` executable so the enabled Hermes `rtk-rewrite` plugin stays active.

Stopping condition: a regression test, NUC worktree build, deploy, service PATH check, and natural timer tick prove no new `rtk binary not found` warning; owned commits are pushed and `workspace-6gq` is closed.

## Decisions

- Fix dotfiles host wiring: module-backed Hermes already includes `pkgs.rtk`; the custom Radar timer omits it from `systemd.services.hermes-radar-cron-tick.path`.
- Keep `rtk-rewrite` enabled; do not remove a useful capability to silence its warning.
- Treat the agents-workspace standalone flake's older package set as unrelated to the host-owned timer PATH.

## Evidence

- Host verified as `MacTraitor-Pro.local`, Darwin arm64.
- NUC has `/etc/profiles/per-user/emiller/bin/rtk`, but the rendered Radar timer PATH omits its Nix store package.
- Radar `errors.log` records `rtk binary not found in PATH` on every natural five-minute tick through 18:29 CDT.
- Focused red test passed as an expected failure; after the fix it and all 21 Python tests pass.
- `hey nuc-wt build` succeeded. `hey nuc-wt switch` activated generation 1108 (`/nix/store/1lbhixwzpwdcpmzqp84s67rikbmb3qkn-…`), whose Radar unit PATH contained `rtk-0.43.0`.
- Concurrent fork deployment generation 1109 superseded generation 1108 before its natural tick. The 18:40 tick therefore reproduced the warning under the overwritten unit; this is deployment contention, not fix verification.
- Coordinating root imposed a global NUC deployment freeze after concurrent branches replaced each other's live units. No further NUC mutation is authorized until one merged integration branch is deployed serially.

## Reviews

- Plan gate attempted with `hey agent-review plan --active-model-family openai --worklog .agents/worklogs/workspace-6gq.md`; blocked at ACP session creation by `RUNTIME: Authentication required`. No findings produced. The user-approved bead and narrow host-path fix remain the operative plan.
- `inspect diff origin/main..HEAD` found no critical/high-risk entities after rebasing; the task-shaped diff is one service PATH entry plus one focused regression test.
- Landing review gate reproduced `RUNTIME: Authentication required` before producing findings.

## Feedback

None.

## Remaining work

- Integrate this branch into the serialized NUC deployment branch.
- After deploy release, verify the Radar unit PATH contains `rtk` and a natural tick emits no new warning.
- Run landing gates, close bead, push, and tag.

## Commits

- `5a12121854` — test(nuc): capture Radar rtk PATH regression
- `91a2374033` — fix(nuc): expose rtk to Radar cron
