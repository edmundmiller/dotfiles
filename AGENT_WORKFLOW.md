---
purpose: Define completion and handoff for substantial agent-authored changes.
applies_to: Multi-session, high-risk, or explicitly workflow-guided dotfiles work.
entrypoint: Establish the intended result and the authority needed to reach it.
verification: hey check, with focused runtime checks where relevant.
update_when: Shared completion, handoff, or approval boundaries change.
---

# Agent workflow

Carry the requested outcome through implementation and proportionate verification,
not merely a plan or intermediate patch. Continue safe local work without
repeated approval; stop at consequential ambiguity or an unauthorized external
action, with the reviewable work and exact next action ready.

## Completion

Run `hey check`; it selects formatting, lint, and affected test suites. Use
task-owned path arguments in a shared dirty checkout. Add behavior-level checks
not covered by that routing; do not repeat checks already run. Read-only work
needs no validation gate, and unchanged evidence needs no rerun merely to stop.
After an input changes, rerun its affected checks. Report unavailable or unrelated
failures as limitations, not passes or obligations to repair others' work.
See [validation](docs/validation.md) for full and platform-only checks.

Update documentation when its ownership, commands, or recovery contract changes.
The [guardrails](docs/agent-guardrails.md) define source ownership and approval
boundaries. Commit, publish, deploy, or clean up only within the user's request;
publication and host activation are not implied by completing local edits.

Cross-model review is optional and runs only on explicit request. It is not a
quality gate. `hey check` never applies repairs to source; use `nix fmt` for
intentional formatting. Model-driven repairs are explicit agent work.

## Durable handoff when needed

For work crossing sessions, `.agents/worklogs/TEMPLATE.md` and `hey agent-start`
can record the outcome, decisions, evidence, and next action. They are optional,
not required artifacts. If Herdr already created the current jj task workspace,
record it rather than creating another one.

`hey agent-sweep --json` inspects existing receipts; a weekly launchd job also
sweeps them. Repeated friction belongs in the smallest owning rule, skill, or
tool, rather than another parallel checklist.
