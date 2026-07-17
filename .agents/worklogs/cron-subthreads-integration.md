# Worklog: cron-subthreads-integration

Status: active

## Objective

Integrate every actionable Hermes cron sub-thread with no new merge commits, prove focused tests and a NUC build, deploy one serialized generation, and close only beads with fresh live or natural-run evidence.

## Decisions

- Keep workers' red/green commits when still relevant; rebase/cherry-pick onto current main and use fast-forward-only landing.
- Treat agents-workspace as canonical runtime source and dotfiles as host wiring.
- Do not land stale tracker-only closure commits before their acceptance evidence exists.
- Batch compatible host changes into one NUC generation.

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
- `hey agent-audit-tests` passed for the changed executor/runtime tests.
- `hey agent-finish` passed test confidence, inventory, agent-quality tests, and drift checks. Its repo-quality subcheck failed because the repository has neither `prek.toml` nor `.pre-commit-config.yaml`; formatting and hook commands stopped at that missing baseline configuration before examining task files.
- Stable generation and remaining natural-run proof are still required before closure.

## Reviews

- Plan review: required gate attempted three ways on 2026-07-16. Claude returned `Authentication required`; Gemini's ACP adapter passed unsupported `acp`; grok-build could not spawn `grok agent stdio`. No independent reviewer was available. Continue with explicit branch, test, build, and live-runtime evidence; rerun landing review before completion.
- Landing review: Claude gate retried after the full build and again returned `Authentication required` before producing findings.

## Feedback

- `hey agents-rollout` still targets missing `~/.openclaw/workspace`; use explicit repo paths for this integration.

## Remaining work

- Verify the restored generation remains stable through repeated ticks.
- Verify Amos Linear sweep at 20:52 CDT and Scintillate `tnote-schedule` at 21:05 CDT.
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
