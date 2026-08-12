# Worklog: done-concurrent-main-reconciliation

Status: active

## Objective

Teach the global `done` skill to reconcile ordinary concurrent advancement of
the remote default branch without duplicating already-landed task changes or
losing later local-only commits. Stop after a deterministic graph regression,
focused checks, skill deployment, hook-backed publication, remote-equality
proof, and preservation proof for unrelated dirty agent-rule files.

## Decisions

- Treat rewritten task commits as landed when stable patch identity proves an
  equivalent commit exists on the refreshed remote default branch.
- Treat later commits outside the explicit task range as separate local-only
  work. Replay only that remainder in a clean integration worktree, then use a
  safe fast-forward to update a dirty default checkout.
- Keep force, reset, stash, unrelated-dirt commits, and hook bypasses forbidden.
- Treat an all-local-refs identity-hook rejection as a separate repair surface,
  not evidence that ordinary remote advancement is irreconcilable.

## Evidence

- Initial `main...origin/main`: 0 ahead, 0 behind after fetch.
- Default checkout dirt is limited to two unrelated agent-rule files and will
  be fingerprinted before landing and re-read afterward.
- The focused concurrent-advance regression constructs
  `A-T1-T2-H` versus `A-U1-U2-T1'-T2'`, classifies the rewritten task patches
  with `git cherry`, replays only `H`, and proves linear history, remote
  equality, and byte-identical dirt. It is a strict expected failure until the
  source contract is fixed.
- `python3 -m unittest tests.test_done_skill -v`: 9 tests passed with the one
  intentional expected failure.
- Planned focused checks: the new unittest regression, all done-skill Python
  tests, deterministic skill-eval tests, skills flake check, installed-source
  parity, repository quality gates, and final landing verifier.

## Reviews

- Plan gate attempted with `hey agent-review plan --active-model-family openai
--reviewer claude`; the configured reviewer stopped with
  `RUNTIME: Authentication required` before producing findings. The exact
  blocker is recorded; the user-approved incident graph remains authoritative.
- Landing review pending.

## Feedback

- Existing guidance says to reconcile destination-local commits but does not
  define how to partition already-landed equivalent task commits from later
  local-only commits after the remote advances.

## Remaining work

- Add and commit the expected-failure regression.
- Implement the skill contract and make the regression pass.
- Run gates, deploy, land, and verify.

## Commits

- Regression commit pending. After landing, create annotated tag
  `agent-work/done-concurrent-main-reconciliation`.
