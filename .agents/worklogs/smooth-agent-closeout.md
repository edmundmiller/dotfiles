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
- Regression commit `83db8f65c` passes with one strict expected failure in both source-contract suites; executable Git simulations pass for non-overlap and overlap.

## Reviews

- Plan reviewer unavailable: `hey agent-review plan` returned `Authentication required` before implementation. Recorded rather than bypassed or misreported.

## Feedback

- Blanket dirty-default blocking causes repeated false blockers even when changed paths do not overlap.

## Remaining work

- Run focused and live-model evals.
- Land and activate the Nix-managed skill.

## Commits

- `83db8f65c` test(done): specify dirty-main fast-forward landing
