# Worklog: return-land-goals

Status: active

## Objective

Define and test a Codex primary/worker return contract that keeps the primary live,
requires machine-readable Luna progress, treats durable goals as checkpoints rather
than wake schedulers, and keeps the goal open through `done` until landing or a
genuine blocker is proven.

## Decisions

- Keep the existing Codex durable-goal mechanism as checkpoint state; do not add a
  scheduler, second goal store, or cross-process wake process.
- Make the primary responsible for waiting on workers and following up
  `CONTINUE`/`PARTIAL` results. A worker `DONE` report is bounded-task completion,
  not repository landing.
- Require `status`, `changed_paths`, `verification`, `landing_state`, and
  `next_action` in every Luna return envelope.
- Keep final landing with the primary and the existing `done` workflow.

## Evidence

- Red contract tests initially failed because the primary and Luna instructions had
  no explicit terminal states or machine-readable return fields.
- Red focused suite passed with three strict expected failures:
  `python3 -m unittest tests.test_codex_model_config tests.test_agent_quality -v`.
- Post-green focused run passed: `python3 -m unittest
tests.test_codex_model_config tests.test_agent_quality` — 32 tests, OK.
- The green commit's pre-commit checks passed: agent instructions, merge
  conflicts, treefmt, skills-lock sync, and conventional commit validation.

## Reviews

- No independent review requested for this bounded contract change.

## Feedback

- The existing “required return shape” wording did not name fields or distinguish a
  worker's bounded completion from repository landing.

## Remaining work

- Parent must integrate these commits, run repository landing checks, and update
  this worklog after authorized landing.

## Commits

- `25fe1cdd6` — red tests for the return-and-land contract.
- Green implementation commit pending.
