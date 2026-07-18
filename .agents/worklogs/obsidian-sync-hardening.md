# Worklog: obsidian-sync-hardening

Status: awaiting mobile audit

## Objective

Harden the intentional hybrid Obsidian Sync topology: Mac Desktop only, NUC Headless only, native mobile clients. Before edits, preserve recoverable Mac and NUC snapshots. Stop propagation on policy drift, unsafe paths, conflict markers, repeated-path loops, or runaway churn. Finish only after focused checks, host deployment, one-peer-at-a-time rollout, and convergence proof; otherwise record the exact external blocker.

## Decisions

- Keep Mac Desktop Sync; do not enable Mac Headless Sync.
- Keep NUC Headless bidirectional because agents edit the vault there.
- Require a shared exclusion subset while preserving device-specific content exclusions.
- On violation, stop the affected writer and alert; never delete or rewrite offending data automatically.
- Mac stop action is a graceful Obsidian quit because no supported external Sync-pause API exists.
- Preserve existing question-mark filenames. Reject colon/control/normalization hazards proven unsafe for the active clients.
- Isolate work in dedicated vault and dotfiles worktrees; preserve unrelated current-tree changes.

## Evidence

- Official guidance: https://obsidian.md/help/sync/headless
- Mac Desktop and NUC Headless were quiesced; concurrent Desktop launches were traced to another Codex task and coordinated to stop.
- NUC service runtime-masked during work.
- NUC ZFS snapshot: `zroot/user/home/emiller@pre-obsidian-sync-hardening-20260717T2310CDT`.
- NUC Restic/R2 snapshot: `7a02cc25`; restored `AGENTS.md` hash matched live `81e70fe9d18f84388ba2c86d40db5f70b8bcfcccb57b9cbab1ae4dc61d9000e1`.
- Mac APFS local snapshot: `com.apple.TimeMachine.2026-07-17-231430.local`.
- Mac clone: `/Users/emiller/Backups/obsidian-vault-pre-hardening-20260717T2315CDT`; 47,967 regular files passed SHA-256 verification.
- Vault regression commit `93acc16651`; implementation commit `0fb4cc059c`.
- Seven tripwire regressions pass. Static guard passes 30,138 visible paths.
- Ten tracked control-character paths were renamed without content changes. One stale invalid archived TaskNote duplicate was removed; its valid archive and active TaskNote remain.
- Nix structural/build check `obsidian-sync-safety-assertions` passes. Mac system evaluates to a Darwin toplevel derivation.
- `hey check` passes all Darwin-compatible checks.
- `hey agent-audit-tests` passes.
- Vault `pnpm check` passes; focused tripwire tests pass 7/7; the changed active TaskNote passes placement, mdbase, contract, and runtime lint.
- Full local NUC toplevel evaluation reaches an existing x86_64-only agent-skills IFD; NUC dry activation remains the authoritative build check.
- NUC dry activation and deployment pass. Final Headless rollout stayed clean for 10+ minutes with repeated `Fully synced`, zero anomalies, and zero rolling churn.
- Mac deployment passes. Desktop reported `Fully synced`, idle, ready, unpaused, and error-free for 10+ minutes; launchd guard remained exit 0.
- Cross-peer common-content manifests contain 29,502 files and match SHA-256 `c334c31c0e1203d0349ed7c6a11f4704be85d60c59c5339a7ca8c6178471e0b1`.
- Manifesting exposed differing tracked `.env`; both writers were frozen, `.env`/`.envrc` were added to the shared policy and both clients, then guards were redeployed.

## Reviews

- Plan gate attempted with the default reviewer and `--reviewer gemini`; both exited before review at `session/new` with `RUNTIME: Authentication required`. No findings were produced. The explicit user-approved plan remains operative; landing review will retry.
- Landing gate retried with default and Gemini reviewers; both failed before review at `session/new` with `RUNTIME: Authentication required`. No findings were produced.

## Feedback

- The vault Sync skill described an obsolete headless-on-Mac topology while the dotfiles module correctly documented Darwin Desktop use.
- Freeze procedures need enforceable coordination because other local agents can reopen the shared Desktop process or restart the NUC service.

## Remaining work

- Audit each mobile client, verify exclusions and canary convergence, then run the final 30-minute all-client quiet window.

## Commits

- Vault `93acc16651` — regression tests.
- Vault `0fb4cc059c` — policy, tripwires, hook, exclusions, safe path repair.
- Vault `19a4ee9f33` — hybrid architecture and recovery runbook.
- Dotfiles `9f0abf8303` — NUC/Mac guards, exclusions, health, eval test, docs.
- Vault `daef7b5bc0`, `67d5bb3126`, `5dbe4b5155` — false-positive regressions and event-loop fix.
- Vault `66c6441403`, `88ed38aa8c` — local environment exclusion regression and fix.
- Dotfiles `ff39da1d12` — deploy local environment exclusions.
