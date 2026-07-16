# Worklog: workspace-rtl.3

Status: source ready; deploy frozen

## Objective

Deploy exactly one Scintillate cron executor on the NUC, reconcile live cron state to canonical jobs, prove stable IDs across two natural ticks, and prove one naturally due run with fresh artifact and delivery evidence.

## Decisions

- Use an isolated systemd cron-tick timer, not the masked interactive gateway. This matches Radar's proven executor and preserves the deliberate gateway disablement.
- Run packaged `hermes cron tick` after activation-owned sync from workspace-ufq.3.6. The standalone `scintillate-hermes` package cannot render deployment topic ids and is intentionally not the host executor.
- Keep host wiring in dotfiles; keep job definitions and sync behavior in agents-workspace.
- Build directly on dotfiles main `8f63bf277`, which contains workspace-ufq.3.6; do not duplicate its sync/prune implementation.

## Evidence

- 2026-07-16 live NUC: `hermes-gateway-scintillate.service` masked/inactive; no Scintillate cron-tick timer.
- Live jobs file after declarative reconciliation: `emiller:users`, mode `0600`, mtime `2026-07-16 18:44:27 -0500`, exactly eight canonical stable IDs.
- `hermes-agent.service` is masked/inactive; no alternate live executor found.
- Canonical current Scintillate runtime already includes `git`; downstream bead confirms Codex auth watchdog is non-canonical legacy state.
- Radar's five-minute isolated timer is healthy and supplies the proven host pattern.
- First executor build rejected the standalone launcher because logical Telegram topics require deployment bindings. The direct Hermes tick avoids duplicating sync and preserves the activation-owned boundary.
- workspace-ufq.3.6 landed in dotfiles main `8f63bf277`; activation reconciled eight canonical jobs and pruned the legacy Codex auth watchdog.
- Regression assertion passed before implementation; it encoded the missing executor as a strict expected failure.
- `hey nuc-wt build` passed on the current integration base: `/nix/store/j7p555284qzrjvyl47yl7yn4nkv7d6g5-nixos-system-nuc-26.11.20260714.18b9261`.
- Built units pass targeted `systemd-analyze verify`; service runs packaged `hermes cron tick`, PATH contains Git and Bun, profile environment is escaped, and the timer targets it every five minutes.
- Global deploy freeze received 2026-07-16 18:42 CDT. No switch or systemd mutation performed by this thread.
- Root's serialized deploy reached generation `/nix/store/crsf4fw8nz5l2ji594z09ypvbsbbsr6w-nixos-system-nuc-26.11.20260714.18b9261`, but did not contain the Scintillate executor; its timer remains absent/inactive.

## Reviews

- Plan review gate attempted with default Claude and Gemini reviewers; both failed before review at ACP session creation with `RUNTIME: Authentication required`. No findings were produced. Proceeding with the explicit user delegation and bounded Radar-pattern plan; landing gate will retry.
- Landing review retried after green build; failed before review at ACP session creation with `RUNTIME: Authentication required`. No findings produced.

## Feedback

None.

## Remaining work

- Push the current-main integration branch and hand exact commits to the coordinating root.
- Await coordinating root's serialized integration deploy.
- After release: prove two natural ticks preserve all eight IDs; prove one naturally due run with artifact and delivery evidence; notify workspace-rtl.3.1.

## Commits

- `c8cdd25bd1` test(cron): capture missing Scintillate executor
- `9b2cbe6ba6` fix(cron): restore Scintillate executor
