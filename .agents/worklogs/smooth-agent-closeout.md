# Worklog: smooth-agent-closeout

Status: active

## Objective

Let agents safely land committed task changes when canonical `main` has unrelated, non-overlapping dirt, while preserving strict refusal for overlapping changes.

## Decisions

- Use a clean temporary integration worktree and explicit task commits.
- Let Git's `merge --ff-only` preflight protect the dirty canonical checkout.
- Keep stashing, resetting, committing, branch switching, and preservation branches forbidden.

## Evidence

- Current `done` skill and evals always block a dirty canonical default checkout.
- The workout-agent change landed safely by clean cherry-pick, remote push, and local `merge --ff-only` without touching unrelated dirt.
- Regression commit `3e82faa94` passes with one strict expected failure in both source-contract suites; executable Git simulations pass for non-overlap and overlap.
- `python3 tests/test_done_skill.py`: 8 passed.
- `bun run test -- done-skill-source.test.ts done-skill-scorer.test.ts`: 4 passed.
- `bun run evals:done`: 4/4 live agent decisions passed, including safe dirty-main continuation and overlapping-dirt refusal.
- `hey agent-finish --worklog .agents/worklogs/smooth-agent-closeout.md`: all Darwin, package, policy, agent-quality, and worklog checks passed.

## Reviews

- Plan reviewer unavailable: `hey agent-review plan` returned `Authentication required` before implementation. Recorded rather than bypassed or misreported.
- Landing reviewer unavailable for the same runtime authentication error after all local gates passed.

## Feedback

- Blanket dirty-default blocking causes repeated false blockers even when changed paths do not overlap.

## Remaining work

- Land and activate the Nix-managed skill.

## Commits

- `3e82faa94` test(done): specify dirty-main fast-forward landing
- `8f092f3f8` fix(done): land safely through dirty main
