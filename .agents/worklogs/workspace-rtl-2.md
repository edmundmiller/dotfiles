# Worklog: workspace-rtl.2

Status: active

## Objective

Restore Betty's NUC cron execution with exactly one isolated timer, canonical job reconciliation, two stable natural ticks, and a fresh naturally due artifact/delivery record. Stop only after live evidence satisfies the bead or an external-time blocker is recorded.

## Decisions

- Preserve the intentionally disabled interactive Betty gateway.
- Add a Betty-specific cron-tick service/timer using the canonical `betty-hermes` launcher, matching Radar's proven executor pattern.
- Keep host wiring in dotfiles; keep Betty's job definition in agents-workspace.

## Evidence

- 2026-07-16 18:31 CDT: `hermes-gateway-betty.service` masked/inactive; no Betty timer.
- Live job `90d60a4f77e0` is enabled but stale at `next_run=2026-06-26T10:15:00-05:00`; no run/error/delivery state.
- `/var/lib/hermes-betty/.hermes/cron/jobs.json` is `emiller:users 0600`.
- Live profile `.env` contains required secret/config keys; no values were read.
- Regression sentinel build: `.#checks.x86_64-linux.nuc-hermes-cron-executors` passed before the fix and proved the timer was absent.
- Fix build: `USER=betty-cron ./bin/hey nuc-wt build` produced `/nix/store/27zrd47c756wrhpdflvw85i4d4j9k8pp-nixos-system-nuc-26.11.20260714.18b9261`.
- Intended executor contract: `.#checks.x86_64-linux.nuc-hermes-cron-executors` passed after the fix.

## Reviews

- Plan review attempted with Claude, Gemini, and Pi reviewers; each ACP runtime returned `Authentication required`. No heterogeneous reviewer was available. Proceeding with narrow red/green assertions and worktree deploy evidence; landing review will be retried.
- Landing review pending.

## Feedback

- Concurrent worktrees overwrite the shared `/tmp/dotfiles-worktree-emiller`; set a unique `USER` suffix for `hey nuc-wt` during parallel agent work.

## Remaining work

- Commit/push and deploy.
- Natural ticks and due-run evidence.

## Commits

- `7fc4f63ff` — regression sentinel and worklog.
