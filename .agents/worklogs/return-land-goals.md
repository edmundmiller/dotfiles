# Worklog: return-land-goals

Status: active

## Objective

Define and test a Codex primary/worker return contract that keeps the primary live,
requires structured Luna progress, treats durable goals as checkpoints rather
than wake schedulers, and keeps the goal open through `done` until landing or a
genuine blocker is proven.

## Decisions

- Keep the existing Codex durable-goal mechanism as checkpoint state; do not add a
  scheduler, second goal store, or cross-process wake process.
- Make the primary responsible for waiting on workers and following up
  `CONTINUE`/`PARTIAL` results. A worker `DONE` report is bounded-task completion,
  not repository landing.
- Require `status`, `changed_paths`, `verification`, `landing_state`, and
  `next_action` in every Luna structured return envelope.
- Keep final landing with the primary and the existing `done` workflow.

## Evidence

- Red contract tests initially failed because the primary and Luna instructions had
  no explicit terminal states or structured return fields.
- Red focused suite passed with three strict expected failures:
  `python3 -m unittest tests.test_codex_model_config tests.test_agent_quality -v`.
- Post-green focused run passed: `python3 -m unittest
tests.test_codex_model_config tests.test_agent_quality` — 32 tests, OK.
- The green commit's pre-commit checks passed: agent instructions, merge
  conflicts, treefmt, skills-lock sync, and conventional commit validation.
- OMP source mapping confirms `config/agents/core.md` is the only global
  `AGENTS.md` content, while `config/omp/commands/go.md` is deployed as the
  task-oriented `/go` prompt by `modules/agents/omp/default.nix`.
- Existing `/go` guidance already made the main agent own integration and told it
  to continue after partial failures, but had no explicit worker wait, structured
  return envelope, or landing-state proof requirement. OMP does not consume the
  Codex `AGENT-16` rule or durable goal runtime.
- Red OMP contract test passed as one strict expected failure:
  `python3 -m unittest tests.test_agent_quality -v` — 26 tests, OK.
- Green OMP-focused run passed: `python3 -m unittest tests.test_agent_quality -v` —
  26 tests, OK.
- The OMP green commit's pre-commit checks passed: OMP config, treefmt, skills-lock
  sync, and conventional commit validation.
- Green wording run passed: `python3 -m unittest tests.test_codex_model_config
tests.test_agent_quality -v` — 34 tests, OK. The prompts and worklog now use
  structured return envelope/report wording; no runtime parser or coordinator was
  added.

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
- `abed3e5c5` — Codex return-and-land contract.
- `f35616224` — red OMP `/go` return-and-land test.
- `375693e32` — OMP `/go` return-and-land contract.
- `a98778cd9` — red regression forbidding the unsupported parser-capability claim.
- `08a6a9513` — structured return wording correction.
