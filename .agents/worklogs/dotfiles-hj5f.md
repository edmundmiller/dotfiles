# Worklog: dotfiles-hj5f

Status: active

## Objective

Deploy canonical `tnote` and Scintillate wrapper fixes to the NUC. Stop only after configuration proof and a natural hourly Hermes run show correct silent output, materially lower peak memory, and unchanged pre-existing vault dirt.

## Decisions

- Current pins are `tnote` `f968abc` and `agents-workspace` `289b1c0`; both predate the profiled fixes and reproduce the expensive paths. Keep the canonical `tnote` fix on `main` at `984117b`, but deploy minimal backport `3dc5771991322a518c27be09efb76eb79f84a2cb` (two task-scoped commits atop the deployed pin) to avoid 136 unrelated intervening commits. Pin wrapper commit `d5c92cac98ea0ac25613429e6bfc00f97a70b9c3`.
- `tnote` makes TaskStore open mdbase with `cache: false`, avoiding the SQL.js import/export of the 166 MB cache while preserving task results. The wrapper skips dirty-worktree snapshot/rebase when `origin/main` already ancestors `HEAD`, and skips Git LFS pre-push when there are no commits to push.
- Use `hey nuc` ownership; never invoke `hermes cron run`.
- Treat deployment proof and natural-run acceptance as separate gates.

## Verification contract

- Build/deploy: `hey nuc-wt build`, `hey nuc dry-activate`, then `hey nuc`; verify the NUC generation, live wrapper SHA, packaged `tnote` path, and successful relevant services.
- Natural output: wait for the job's recorded `next_run_at`; require a later successful `last_run_at`, silent/no-error artifact classification, and no scheduler-owned commit on a no-op.
- Performance: read the natural systemd tick's journal resource line; require peak memory materially below the 2.5 GiB baseline and wall time materially below 59.968 s.
- Vault safety: fingerprint `HEAD`, porcelain status, binary unstaged/staged diffs, stash list, and untracked content immediately before deployment and the natural run; require exact equality except any separately identified external writer event.
- Rollback: if build, activation, runtime correctness, or performance fails, revert the two input-pin changes, redeploy with `hey nuc`, and verify the prior NUC generation and Hermes services; the runbook's `hey nuc-rollback` remains the immediate activation fallback.

## Evidence

- NUC natural baseline, 2026-07-21 18:26 CDT: `journalctl -u hermes-scintillate-cron-tick.service` reported 2.5 GiB peak/59.968 s wall; artifact metadata was 149 bytes and classified silent without printing content.
- Same installed binary against an exact temporary vault copy: `env TN_VAULT_PATH=<copy> /run/current-system/sw/bin/time -v tnote schedule run --algorithm urgency --json`. Cache enabled: 2,911,432 KiB/59.50 s. Blocking only the copy's `.mdbase` cache path: 1,182,568 KiB/9.66 s. JSON SHA was identical.
- Fixed source against an exact temporary vault copy: `env TN_VAULT_PATH=<copy> /run/current-system/sw/bin/time -v bun run packages/tn/index.ts schedule run --algorithm urgency --json`; 1,706,516 KiB/12.38 s.
- Minimal backport A/B against identical temporary vault copies: deployed binary 2,994,832 KiB/57.29 s versus backport 1,462,024 KiB/7.46 s. JSON bytes/SHA, resulting binary Git diff SHA, and status SHA were identical; only the deployed binary rewrote `.mdbase/cache.sqlite`.
- Fixed wrapper against an exact temporary vault copy and no-op fake `tnote`: `env PATH=<fake-bin> TNOTE_SCHEDULE_VAULT=<copy> /run/current-system/sw/bin/time -v bun run tnote-schedule-safe.ts`; 44,156 KiB/0.29 s. Pre/post status and binary-diff SHAs matched; stash count remained zero.
- Every vault copy was created beneath `/tmp` and deleted by an exit trap; no profile command targeted the live vault for writes.
- Upstream verification: `git ls-remote` reports canonical `tnote` fix `984117b` and wrapper `d5c92ca` on `main`; deploy backport `3dc5771` is pushed at `refs/heads/codex/tnote-schedule-memory-backport`.
- Test ownership: upstream `tnote` regression tests assert cache bypass/output behavior and upstream wrapper tests assert no-op sync skipping; this repo's Nix checks assert package/provider/runtime wiring after the pins change.
- Config proof: `hey nuc-wt build` produced `/nix/store/w9s8s52zsfv7svwcyxp02l6s8ldldk2s-nixos-system-nuc-26.11.20260714.18b9261`; `hey nuc dry-activate` succeeded. NUC builds of `nuc-scintillate-runtime-access` and `nuc-hermes-cron-executors` passed.
- Run receipt: `/Users/emiller/.local/state/dotfiles-agent-runs/a1169ef3c1f1/20260722T002052Z-34e101cbe1da.json`.

## Reviews

- Plan review: default reviewer was auth-blocked; heterogeneous OpenCode review completed with active family `gpt-5`. The run receipt started at `b074d5b`, and both review passes ran while Git showed only the issue/worklog changes and no Nix diff, proving the gate preceded implementation. Resolved provenance, implementation-description, current/target-pin, success-criteria, rollback, ephemeral-copy, and test-scope findings above.
- Landing review: pending.

## Feedback

- `hey update` does not currently inject the local GitHub credential for private `github:` inputs, although rebuild paths do. The unauthenticated attempt changed no state; the retry supplied the existing `gh` credential through `NIX_CONFIG` without printing it.

## Remaining work

- Update inputs, build, deploy, verify canonical runtime paths.
- Observe and verify the next natural hourly run.

## Commits

- `34f4d66` regression test on the deployed `tnote` base.
- `3dc5771` minimal `tnote` cache-bypass backport.
- `d5c92ca` Scintillate no-op Git sync fix.
- `cf3bb81` deployment issue and plan record.
