---
purpose: Define completion and handoff for substantial agent-authored changes.
applies_to: Multi-session, high-risk, or explicitly workflow-guided dotfiles work.
entrypoint: Establish the intended result and the authority needed to reach it.
verification: Focused evidence and hey check --worktree, with runtime checks where relevant.
update_when: Shared completion, handoff, or approval boundaries change.
---

# Agent workflow

Carry the requested outcome through implementation and proportionate verification,
not merely a plan or intermediate patch. Continue safe local work without
repeated approval; stop at consequential ambiguity or an unauthorized external
action, with the reviewable work and exact next action ready.

## Completion

Use the affected subsystem's check, then `hey check --worktree`, the shared
repository validation command. Behavior changes need evidence at the affected
surface; generated configuration benefits from its native validator. Prose-only
changes do not require host builds, activation, or live model runs. Report
unavailable checks as limitations, not passes.

Update documentation when its ownership, commands, or recovery contract changes.
The [guardrails](docs/agent-guardrails.md) define source ownership and approval
boundaries. Commit, publish, deploy, or clean up only within the user's request;
publication and host activation are not implied by completing local edits.

Cross-model review is optional and runs only on explicit request. It is not a
quality gate. Deterministic formatters/checks may repair their supported scope;
model-driven repairs are explicit agent work, not implicit Git hooks.

## Durable handoff when needed

For work crossing sessions, `.agents/worklogs/TEMPLATE.md` and `hey agent-start`
can record the outcome, decisions, evidence, and next action. They are optional,
not required artifacts. If Herdr already created the current jj task workspace,
record it rather than creating another one.

`hey agent-sweep --json` inspects existing receipts; a weekly launchd job also
sweeps them. Repeated friction belongs in the smallest owning rule, skill, or
tool, rather than another parallel checklist.
