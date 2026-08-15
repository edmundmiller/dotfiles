# Worklog: refactor-done-evidence-bounded

Status: active

## Objective

Refactor the global `done` skill into an evidence-bounded dispatcher with deterministic closeout inspection, schema-v2 resumable receipts, Git/jj/GitHub reference workflows, Nix activation, installed readback, and verified landing. Stop only after authoritative remote equality and safe task-worktree cleanup are proven, or at an exact external blocker.

## Decisions

- Bare `done` authorizes full closeout; narrower requests retain a strict authority envelope.
- Preserve all existing verifier and teardown interfaces and v1 receipt compatibility.
- Use a Python-stdlib JSON helper for read-only snapshot, classification, and preservation verification.
- Keep partial closeout outcomes open and revalidate external state before resuming.
- Work from an isolated sibling worktree because the primary checkout contains unrelated staged changes.

## Evidence

- Initial source and authoritative `origin/main` both resolved to `dbffd938be6b6fd15afcdb45d727732e27fbf3c5`.
- Primary checkout unrelated dirt was left untouched.
- Skill-quality deterministic validator passed before implementation in the planning session.
- Active receipt: `/Users/emiller/.local/state/dotfiles-agent-runs/35f53043c8d0/20260815T223533Z-fe57500817c8.json`.
- Focused Python contract suite passed: 60 tests before the final provenance tightening; the receipt and closeout subset then passed 30 tests.
- TypeScript unit suite passed: 7 files and 74 tests; typecheck passed.
- The `done` decision evaluation passed all 6 scenarios on both `gpt-5.6-terra` and `gpt-5.6-sol`.
- The installed jj 0.43.0 path was exercised with a real cloned repository; structured snapshot and verify-mode classification behaved as specified.
- `./bin/hey check --worktree`, `hey agent-audit-tests`, and `hey agent-finish` passed against the complete staged source.

## Reviews

- User completed and confirmed the built-in grilling design interview.
- Cross-model plan review was not requested; canonical workflow makes it optional.

## Feedback

- The existing closeout policy encodes deterministic VCS classifications in prose; move parseable state into tested helpers while retaining judgment and authority boundaries in the skill.

## Remaining work

- Run the repository-wide gate, commit, activate and verify the installed skill, land, tag, prove remote equality, and safely clean up the task worktree.

## Commits

- `a7f8f87c9 refactor(done): make closeout evidence-bounded`
