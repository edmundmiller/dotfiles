# Worklog: Oracle review fixes

Status: local history reconciliation; no push authorized

Reconciliation note: upstream already supplies deployment isolation and vault
sync safeguards. The user dropped the obsolete Radar fix and its test.
The evidence below records checks before reconciliation, not a new full-suite
pass. Latest review still flags repeated Claude-skills activation and Herdr
raw-input permission bypasses. This history-only pass does not fix them.

## Objective

Fix the six findings from the requested merge-base review and its documentation drift. Preserve unrelated work and do not activate host changes.

## Decisions

- Keep native Pi edit/write tools instead of Codex conversion until its hooks preserve permission checks. Guard exec_command and current Herdr command dispatch; block unchecked patch/stdin writes.
- Give each remote deployment its own disposable source snapshot.
- Verify registered jj workspace paths and shared repository identity before deletion; fail closed on inspection errors.
- Preserve unmanaged Claude skills in a recoverable backup, refusing collisions.
- Restrict UNAS exports and firewall source rules to Tailscale 100.64.0.0/10 and the verified home LAN 192.168.1.0/24.

## Evidence

- NUC hostname and Linux verified; `ip -4 route` confirms the LAN /24.
- Focused Pi bridge: 13 tests passed, including alternate commands, jj workdir, unchecked patches, and stdin polling.
- Remote deployment Nushell tests passed for unique snapshots and sync failure.
- Seven executed Claude-skills migration tests passed.
- Worker built jw and exercised real disposable jj repositories; its ZUnit runner fails even on baseline, so it is not a passing test gate.
- Parent reproduced a same-repository sibling-symlink deletion, added duplicate-root rejection, and confirmed custom-path deletion succeeds while the sibling remains intact. Rebuilt jw successfully and passed its AST scan.
- Host-permission checks confirmed UNAS export ranges and no global TCP 2049 opening.
- Pi bridge typecheck and settings schema validation passed. `nix flake update skills-catalog` completed with no root lock delta.
- Test-confidence audit passed. The first broad gate failed because sources changed during evaluation; the stable retry was interrupted during dependency builds and produced no final result. Neither is a broad-gate pass. Log: `.amp/in/artifacts/oracle-fixes-finish.log`.
- Five database sidecars are ignored without deleting them. Unrelated service changes and Beads JSONL remain unstaged.

## Reviews

These changes address the user's requested Oracle findings. Plan/landing command gates require unavailable acpx; no pass claimed.

## Feedback

Use explicit NixOS sudo wrapper and repository-local hey. Do not amend commits here: the post-rewrite Beads hook previously conflicted with unrelated dirt.

## Remaining work

Publication remains blocked: a fresh fetch shows 5,481 local-only and 6,497 remote-only commits before this fix commit. No rebase, force-push, or deployment was attempted. The full gate, missing-acpx landing gate, and live host checks remain incomplete.

## Commits

Local commit: `fix: address oracle review safety findings`, carrying this thread's Amp-Thread-ID. No publication or tag until history reconciliation is agreed.
