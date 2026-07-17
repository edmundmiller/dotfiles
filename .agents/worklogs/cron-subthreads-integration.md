# Worklog: cron-subthreads-integration

Status: active

## Objective

Integrate every actionable Hermes cron sub-thread with no new merge commits, prove focused tests and a NUC build, deploy one serialized generation, and close only beads with fresh live or natural-run evidence.

## Decisions

- Keep workers' red/green commits when still relevant; rebase/cherry-pick onto current main and use fast-forward-only landing.
- Treat agents-workspace as canonical runtime source and dotfiles as host wiring.
- Do not land stale tracker-only closure commits before their acceptance evidence exists.
- Batch compatible host changes into one NUC generation.
- Serialize every mutating NUC deployment and reject snapshots not based on current dotfiles main unless explicitly overridden.

## Evidence

- Current agents-workspace main and dotfiles origin/main fetched 2026-07-16.
- Branch ancestry and `git cherry` audited for all cron sub-threads.
- Agents-workspace Amos model contract passed via Python and `.#checks.aarch64-darwin.amos-cron-model-contract`; commits landed FF-only on main.
- Dotfiles focused Python tests passed for executor wiring and Radar runtime.
- `.#checks.aarch64-darwin.nuc-hermes-cron-external-executor` executes five tests against the patched pinned Hermes source; no skip-only proof remains.
- NUC x86_64 checks passed: executor wiring, Scintillate runtime access, Radar runtime, and external executor reporting.
- Initial NUC check exposed immutable-store chmod from copying symlinked Hermes files. The integrated fix dereferences them into writable output; all four checks then passed.
- Full NUC build passed after the final rebase onto dotfiles main: `/nix/store/2gvvj6akdnx6ia75b0rg8x13nhpgbrz3-nixos-system-nuc-26.11.20260714.18b9261`.
- Scintillate's first natural `tnote-schedule` run exposed quoted Unicode paths being misclassified as outside `01_Tasks/`. Agents-workspace regression/fix commits `69c0fae` and `c0cbdb0` passed the focused behavior test; dotfiles pin `1fc356dac4` passed a full NUC build.
- Integrated generation `jw994877ibm5wd8zfawas7f7wv49wayg` proved all four timers, masked gateways, ownership, Radar external-executor status, runtime PATHs, and repeated clean ticks. Amos' watchdog and Scintillate's corrected script remained pending.
- A separate canonical-checkout deploy at 20:22 CDT replaced the integrated generation with `wss3x0ls2qd2s8sjw2ddvr7sz8z18prh`, temporarily removing Amos, Betty, and Scintillate. The cron verification tasks detected the drift read-only.
- The integration branch fast-forwarded to latest linear dotfiles main `1610de4996` and restored generation `xi3j09fbsppj56h4nkwxv4nbv08sivhw` at 20:29 CDT. All four timers are enabled/active and all gateways masked. The automatic 20:29 Amos run advanced watchdog `20762267078d` to 20:59:59, status `ok`, and wrote a 1277-byte `[SILENT]` artifact with no model 404.
- Amos' natural Linear sweep completed `ok` at 20:58:37 with no model 404. Its artifact exposed separate missing-skill and Linear-auth blockers tracked as `workspace-amos-cron-skill-materialization-x1c` and `workspace-amos-linear-cron-auth-3qi`; Amos executor/model beads are closed.
- Scintillate's natural 21:06:37 run proved the quoted-path fix but exposed a mutable tnote source import failure: missing `@tn/tasknotes`. Agents-workspace commits `f6044e8` and `41ac4c4` replace that import with packaged `tnote schedule run --algorithm urgency --json`; focused Scintillate and Amos checks passed.
- Dotfiles pin `1be3467caa` passed a full NUC build and deployed generation `jgj1nqiba9axb94xlf8qfsc7pk0zy60a` at 21:17 CDT. All four timers are enabled/active, all gateways masked/inactive, job files are `emiller:users 0600`, and Scintillate PATH contains packaged `tnote 0.3.0`. Its deployed script contains no `TNOTE_REPO` or raw package imports.
- Scintillate's natural 22:11:45 run reached packaged tnote and commit, then failed because the vault's checkout hook could not resolve `git-lfs`. Dotfiles regression/fix commits `c31d66322` and `657fd72f2` add `git-lfs` to the isolated cron PATH. The x86_64 runtime check and full NUC build passed; generation `iw5l2mnzxyffhfffzvhiqvwy8ccbfnic` deployed with all four timers active, gateways masked, and both `git-lfs 3.7.1` and `tnote 0.3.0` in Scintillate's service PATH.
- The failed commit left 2323 automation-staged `01_Tasks` paths. The script had verified no pre-existing staged changes; root reset only that index path, leaving zero staged paths and preserving 2331 dirty/untracked working paths. No vault content was discarded.
- The 22:20 switch again replaced a concurrently deployed non-main generation: activation removed Homebox while restoring current linear dotfiles main. This reconfirms `workspace-x6l`; avoid further switches until deploy serialization is fixed.
- Dotfiles regression/fix commits `d0cf0ca35` and `5f5cf7bbc` now serialize mutating NUC deployments with `/run/lock/nixos-deploy.lock`, record owner diagnostics, reject stale local snapshots, preserve parallel build mode, and forward interruption safely. Hermetic checks pass on Darwin and x86_64 Linux; `f832b90c3` fixes the Linux test package. A live stale smoke was rejected before activation with exit 65. `workspace-x6l` is closed.
- Homebox was rebased and integrated linearly as `7e8941d38`; the combined generation preserved Homebox HTTP 200, all four Hermes timers, masked gateways, and the deploy guard.
- Scintillate's natural 23:15:49 run cleared the Unicode, mutable-import, and git-lfs blockers, then exposed whole-tree staging: 2325 pre-existing/untracked active-task paths hit the vault status hook. Root verified every staged path was under `01_Tasks`, reset only that index, and preserved all working content.
- Agents-workspace red/green pairs `bed173d`/`035f613` and `253664a`/`247175f` make failed commits clear only automation staging and commit only paths newly dirtied by the scheduler. Four focused tests pass, including Unicode paths, failed-hook cleanup, packaged tnote, and pre-existing untracked exclusion.
- Dotfiles `0d3f0dd25` pins those fixes. Full NUC build `/nix/store/l6xyhy9kyh2wwjbphw0b79qx5lxz6dab-nixos-system-nuc-26.11.20260714.18b9261` is live with all four timers active, gateways masked, Homebox active, the corrected script materialized, and zero staged vault paths.
- `hey agent-audit-tests` passed for the changed executor/runtime tests.
- `hey agent-finish` passed test confidence, inventory, agent-quality tests, and drift checks. Its repo-quality subcheck failed because the repository has neither `prek.toml` nor `.pre-commit-config.yaml`; formatting and hook commands stopped at that missing baseline configuration before examining task files.
- Scintillate's natural `tnote-schedule` run at 00:20:08 CDT on generation `l6xyhy9kyh2wwjbphw0b79qx5lxz6dab` completed `ok`, advanced to 01:20:08, wrote a fresh 149-byte valid silent no-op artifact, cleared `last_error`, matched none of the prior runtime/staging blockers, and left the vault staged count at zero. `workspace-rtl.3.1` and `workspace-rtl.3` closed in agents-workspace `9194d5e`.
- At 07:44 CDT the NUC was on generation `s10lp05qnvqai4xa30pl55wal0xqs25m`, whose `nixos-version --json` configuration revision is `e0e356f7ba1b98e335f0751a70bb1fff9c8ad90d`. That revision is an ancestor of current dotfiles `origin/main`; the only later commit is heartbeat documentation. Betty's timer/gateway topology, service environment, state ownership, stable job ID, and 10:15 due time remained intact. Remaining verifiers now qualify generations by source-revision ancestry plus runtime invariants instead of brittle store-path equality.

## Reviews

- Plan review: required gate attempted three ways on 2026-07-16. Claude returned `Authentication required`; Gemini's ACP adapter passed unsupported `acp`; grok-build could not spawn `grok agent stdio`. No independent reviewer was available. Continue with explicit branch, test, build, and live-runtime evidence; rerun landing review before completion.
- Landing review: Claude gate retried after the full build and again returned `Authentication required` before producing findings. Final retry at 2026-07-16 23:43 CDT with `hey agent-review landing --active-model-family openai --worklog .agents/worklogs/cron-subthreads-integration.md` failed identically at `session/new`; no review findings were produced.

## Feedback

- `hey agents-rollout` still targets missing `~/.openclaw/workspace`; use explicit repo paths for this integration.
- Scintillate verifier/coordinator wakeups completed and its two tasks were archived. Codex heartbeat `BYHOUR` values are evaluated as UTC: the first Betty coordinator fired early at 05:33 CDT, before the 10:15 job. Remaining schedules were corrected and re-read active: Betty verifier/coordinator at 15:30/15:33Z (10:30/10:33 CDT), Radar verifier at 21:35Z (16:35 CDT).

## Remaining work

- Verify Betty at 10:15 CDT and Radar at 16:30 CDT on 2026-07-17; close only beads whose natural-run evidence satisfies acceptance.

## Commits

- Agents-workspace `273fa9a`, `52b5eeb` — Amos model regression/fix; FF-only on main.
- Dotfiles `4f9a37fec` — remove duplicate Amos cron ownership repair.
- Dotfiles `8e04a6a47`, `e8db61d91` — Scintillate executor regression/fix.
- Dotfiles `4ecbf3160`, `3c155aaf9` — timer-aware Hermes health regression/fix.
- Dotfiles `4b2923e55` — execute external-executor regression in Nix checks.
- Dotfiles `7692da380` — pin integrated agents-workspace main.
- Dotfiles `e85c3568f` — dereference patched Hermes CLI out of the immutable store.
- Agents-workspace `69c0fae`, `c0cbdb0` — quoted-path regression/fix.
- Dotfiles `1fc356dac4` — pin corrected Scintillate script.
- Agents-workspace `f6044e8`, `41ac4c4` — mutable-import regression/packaged tnote fix.
- Dotfiles `1be3467caa` — pin packaged tnote scheduler.
- Dotfiles `c31d66322`, `657fd72f2` — missing-git-lfs regression/runtime fix.
- Dotfiles `d0cf0ca35`, `5f5cf7bbc`, `f832b90c3` — deploy serialization regression/fix and hermetic Linux check.
- Dotfiles `7e8941d38` — integrate private Homebox pilot without losing cron runtime.
- Agents-workspace `bed173d`, `035f613` — failed-hook staged-residue regression/fix.
- Agents-workspace `253664a`, `247175f` — unrelated active-task staging regression/run-owned staging fix.
- Dotfiles `0d3f0dd25` — pin run-owned Scintillate scheduler.
