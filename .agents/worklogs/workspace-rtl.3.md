# Worklog: workspace-rtl.3

Status: source ready; deploy frozen

## Objective

Deploy exactly one Scintillate cron executor on the NUC, reconcile live cron state to canonical jobs, prove stable IDs across two natural ticks, and prove one naturally due run with fresh artifact and delivery evidence.

## Decisions

- Use an isolated systemd cron-tick timer, not the masked interactive gateway. This matches Radar's proven executor and preserves the deliberate gateway disablement.
- Run packaged `hermes cron tick` after activation-owned sync from workspace-ufq.3.6. The standalone `scintillate-hermes` package cannot render deployment topic ids and is intentionally not the host executor.
- Keep host wiring in dotfiles; keep job definitions and sync behavior in agents-workspace.
- Consume workspace-ufq.3.6's exact agents-workspace pin; do not duplicate its sync/prune implementation.

## Evidence

- 2026-07-16 live NUC: `hermes-gateway-scintillate.service` masked/inactive; no Scintillate cron-tick timer.
- Live jobs file: `emiller:users`, mode `0600`, mtime `2026-06-23 13:16:58 -0500`.
- `hermes-agent.service` is masked/inactive; no alternate live executor found.
- Canonical current Scintillate runtime already includes `git`; downstream bead confirms Codex auth watchdog is non-canonical legacy state.
- Radar's five-minute isolated timer is healthy and supplies the proven host pattern.
- First executor build rejected the standalone launcher because logical Telegram topics require deployment bindings. The direct Hermes tick avoids duplicating sync and preserves the activation-owned boundary.
- workspace-ufq.3.6 landed as agents-workspace `500f95c` and dotfiles pin `6186124f4`; activation reconciled eight canonical jobs and pruned the legacy Codex auth watchdog.
- Regression assertion passed before implementation; it encoded the missing executor as a strict expected failure.
- `hey nuc-wt build` passed for the implementation: `/nix/store/pcfavf8qnnm2kc8dh33dnv2q85nc045n-nixos-system-nuc-26.11.20260714.18b9261`.
- Built units pass targeted `systemd-analyze verify`; service runs packaged `hermes cron tick`, PATH contains Git and Bun, profile environment is escaped, and the timer targets it every five minutes.
- Global deploy freeze received 2026-07-16 18:42 CDT. No switch or systemd mutation performed by this thread.

## Reviews

- Plan review gate attempted with default Claude and Gemini reviewers; both failed before review at ACP session creation with `RUNTIME: Authentication required`. No findings were produced. Proceeding with the explicit user delegation and bounded Radar-pattern plan; landing gate will retry.
- Landing review retried after green build; failed before review at ACP session creation with `RUNTIME: Authentication required`. No findings produced.

## Feedback

None.

## Remaining work

- Push source branch and hand exact integration commits to the coordinating root.
- Await coordinating root's serialized integration deploy.
- After release: prove two natural ticks preserve all eight IDs; prove one naturally due run with artifact and delivery evidence; notify workspace-rtl.3.1.

## Commits

- `4056d2f0e2` test(cron): capture missing Scintillate executor
- `bbfedb693f` chore(nuc): deploy declarative Hermes cron sync
- `a151446cbb` fix(cron): restore Scintillate executor
