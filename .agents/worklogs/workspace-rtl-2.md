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
- Deployment generation `/nix/store/fxsfdm1ng2kmhaa81846vg8l0m4c5krl-nixos-system-nuc-26.11.20260714.18b9261` enabled the Betty timer while keeping the interactive gateway masked.
- First natural tick ran 2026-07-16 18:41:30–18:41:57 CDT with systemd result `success`; it preserved job ID `90d60a4f77e0`, advanced `next_run` to 2026-07-17 10:15 CDT, and wrote a fresh 2,951-byte artifact.
- The due job recorded `last_status=error`: a stale root-owned `logs/agent.log` caused `PermissionError`, and bare `deliver=discord` lacked `DISCORD_HOME_CHANNEL` despite the channel being present in `config.yaml`.
- Hermes 0.18.2 scheduler source confirms bare platform delivery resolves through platform-specific home-target environment variables. Betty's follow-up fix exports `DISCORD_HOME_CHANNEL` from the canonical NUC Discord binding.
- Shared cron ownership/reconciliation is intentionally excluded here; `workspace-ufq.3.6` owns that module-wide repair.
- Local source evaluation confirms `DISCORD_HOME_CHANNEL=1494160879803957379` in the Betty unit and evaluates `.#checks.x86_64-linux.nuc-hermes-cron-executors`. Full local `nix flake check --no-build` reached the expected `x86_64-linux` derivation platform mismatch on `aarch64-darwin` after evaluating the NUC configuration.

## Reviews

- Plan review attempted with Claude, Gemini, and Pi reviewers; each ACP runtime returned `Authentication required`. No heterogeneous reviewer was available. Proceeding with narrow red/green assertions and worktree deploy evidence; landing review will be retried.
- Landing review pending on the merged cron integration branch.

## Feedback

- Concurrent worktrees overwrite the shared `/tmp/dotfiles-worktree-emiller`; set a unique `USER` suffix for `hey nuc-wt` during parallel agent work.

## Remaining work

- Rebase onto the shared cron ownership/reconciliation commit, then push the conflict-free Betty range.
- Coordinated merged deploy preserving Betty, Amos, Radar, and Scintillate units.
- Two stable natural ticks and a fresh naturally due artifact/delivery record from that merged generation.

## Commits

- `c541034c8b` — regression sentinel and worklog.
- `28f0583154` — isolated Betty executor/timer.
- `1417118677` — Discord delivery regression sentinel.
- `22318e5f81` — binding-derived Discord home target.
