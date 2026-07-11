---
purpose: Canonical risk-gated workflow for agent-authored changes.
applies_to: Broad, autonomous, high-risk, or multi-session tasks in this repository.
entrypoint: Copy .agents/worklogs/TEMPLATE.md and use hey agent-* commands.
verification: hey agent-finish, runtime smoke checks, heterogeneous landing review.
ownership: Agents update this contract when repeated workflow evidence exposes drift.
status: Canonical; root and nested AGENTS.md route here for qualifying work.
---

# Agent workflow

Use this workflow when work is broad, autonomous, high-risk, or likely to cross sessions. Small changes use the same evidence standards without a worklog or Git tag.

## Start

1. Inspect repository, runtime, issue state, and unrelated dirt.
2. Copy `.agents/worklogs/TEMPLATE.md` to `.agents/worklogs/<issue-or-slug>.md`.
3. Define the outcome, stopping condition, and verification surfaces before editing.
4. Discover relevant docs by searching their first seven lines for `purpose`, `applies_to`, or `ownership`.

## Research and plan gate

- Keep research source-backed and record consequential findings in the worklog.
- Before high-risk implementation, run `hey agent-review plan --active-model-family <family> --worklog <path>`.
- Resolve findings or record why they do not apply. Same-family review does not satisfy the gate.

## Implement

- Use red/green/refactor for behavior changes. Run focused tests continuously.
- Run the actual application, service, generated artifact, or runtime surface. A build alone is insufficient when user-visible behavior can be checked.
- Update the canonical system docs in the same change. Prefer metadata and generated inventories over hand-maintained file lists.
- Add deterministic tools under `bin/` when repeated work warrants them. Keep commands non-interactive, structured, bounded, and secret-safe.
- Use formatters and deterministic `--fix` tools directly. Model-driven repairs are explicit agent actions, never implicit Git hooks.

## Landing gate

1. Run focused tests, then `hey agent-audit-tests` and `hey agent-finish --worklog <path>`.
2. For UI/performance paths, add or update the subsystem manifest command before claiming those checks pass.
3. Run `hey agent-review landing --active-model-family <family> --worklog <path>` and resolve findings.
4. Update evidence, feedback, remaining work, commits, and status in the worklog.
5. Commit, push, verify upstream state, then create and push annotated tag `agent-work/<issue-or-slug>`.

`PASS` requires an exercised check. `NOT_APPLICABLE`, `SKIP`, no tests collected, and missing validators are not passes.

## Periodic maintenance

- Run `hey agent-sweep` across recent commits and file concrete findings in `br`.
- Periodically synthesize repeated worklog feedback into durable rules, skills, linters, docs, or commands.
- Run false-confidence audits after test infrastructure changes and investigate skips, vacuous assertions, over-mocking, and tests that never reach production behavior.

The quality manifest is trusted repository code: `agent-finish` executes its commands through the shell. Review manifest changes like scripts; never interpolate secrets or untrusted input into commands.
