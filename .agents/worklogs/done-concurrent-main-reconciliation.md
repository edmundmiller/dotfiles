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
- `python3 -m unittest tests.test_done_skill -v`: 9 tests passed after removing
  the strict expected-failure marker.
- `cd tests/skill-evals && bun run test`: 7 files and 72 tests passed.
- The source now records the task boundary before fetch, distinguishes remote
  patch equivalents from later local-only commits, replays only remaining
  commits in a clean integration worktree, fingerprints dirty paths, and
  separates all-local-refs hook failures from ordinary remote advancement.
- `nix flake check ./skills`, focused `hey agent-audit-tests`, and `hey check`
  passed.
- `hey agent-finish --changed ... --worklog ...` passed repository quality,
  37 agent-quality tests, instruction validation, test confidence, inventory,
  and worklog validation.
- `hey rebuild` completed Darwin/Home Manager activation from the task branch;
  repository source and installed `~/.agents/skills/done/SKILL.md` are
  byte-identical.
- Planned focused checks: the new unittest regression, all done-skill Python
  tests, deterministic skill-eval tests, skills flake check, installed-source
  parity, repository quality gates, and final landing verifier.

## Reviews

- Plan gate attempted with `hey agent-review plan --active-model-family openai
--reviewer claude`; the configured reviewer stopped with
  `RUNTIME: Authentication required` before producing findings. The exact
  blocker is recorded; the user-approved incident graph remains authoritative.
- Landing review reproduced the same `RUNTIME: Authentication required`
  boundary before producing findings. Manual semantic review found only the
  regression graph, skill contract, and this worklog.

## Feedback

- Existing guidance says to reconcile destination-local commits but does not
  define how to partition already-landed equivalent task commits from later
  local-only commits after the remote advances.

## Remaining work

- Land with the installed `done` skill, prove remote equality and dirty-file
  preservation, finish the receipt, flush task state, and tag the result.

## Commits

- `1753a1f99` — regression graph with strict expected failure.
- Fix commit (amended after final evidence) follows. After landing, create
  annotated tag
  `agent-work/done-concurrent-main-reconciliation`.
