---
purpose: Canonical evidence-gated workflow for agent-authored changes.
applies_to: Broad, autonomous, high-risk, or multi-session tasks in this repository.
entrypoint: Define the outcome, run focused checks, then run hey check --worktree.
verification: Focused checks, hey check --worktree, runtime smoke checks, and landing proof.
update_when: Repeated workflow evidence exposes drift in this contract.
---

# Agent workflow

Use this workflow when work is broad, autonomous, high-risk, or likely to cross sessions. Humans and agents use the same repository checks. Worklogs and run receipts are optional bookkeeping for work that benefits from a durable handoff; they are not quality gates.

## Start

1. Inspect repository, runtime, issue state, and unrelated dirt.
2. Define the outcome, stopping condition, and verification surfaces before editing.
3. Route through root and nearest nested `AGENTS.md`. Load every matching skill before acting.
4. Find canonical docs by searching the first seven lines for `purpose`, `applies_to`, or `update_when`.
5. For multi-session work that needs a durable handoff, use `.agents/worklogs/TEMPLATE.md` and `hey agent-start`. If Herdr already created the current jj task workspace, record that workspace instead of creating another one. Do not create bookkeeping merely to satisfy this document.

## Research

- Keep research source-backed and record consequential findings in the task's durable notes when they exist.
- Cross-model review is optional and runs only when the user explicitly requests it; reviewer availability never gates implementation or landing.

## Implement

- Use red/green/refactor for behavior changes. Run focused tests continuously.
- For a reproduced bug, add a regression at the public seam. When strict
  expected-failure support exists and split history improves review, first land
  a green expected-failure test commit, then fix and flip it. Otherwise keep one
  green change. Never commit a red suite.
- Run the actual application, service, generated artifact, or runtime surface. A build alone is insufficient when user-visible behavior can be checked.
- Add deterministic tools under `bin/` when repeated work warrants them. Keep commands non-interactive, structured, bounded, and secret-safe.
- Use formatters and deterministic `--fix` tools directly. Model-driven repairs are explicit agent actions, never implicit Git hooks.

## Keep documentation true

- Update canonical docs in the same change as behavior, ownership, commands, or recovery.
- Start each canonical doc with the YAML summary in [docs/agent-guardrails.md](docs/agent-guardrails.md); close it by line 7.
- Name the source of truth and a live check. Generate facts that would otherwise be copied.
- If docs and reality disagree, verify reality, fix the doc and its enforcement, then record recurring friction in the task's durable notes when they exist.
- Move repeated feedback into the smallest existing durable surface: doc, rule, skill, linter, or command. Do not create a parallel convention.

## Landing gate

1. Run focused tests and exercise the affected runtime surface.
2. Run `hey check --worktree`. This is the shared local validation command used by people, Git hooks, CI, and agent completion hooks.
3. Update any worklog, receipt, or issue that the task actually uses.
4. When publication is authorized, use the global `done` skill to shape commits, reconcile, publish, prove remote equality, and clean up.

A successful command is evidence only for the behavior it exercised. Missing validators, skipped tests, and untested runtime behavior are not passes.

## Periodic maintenance

- A weekly launchd job runs `agent-sweep` over any durable receipts that were created. Run `hey agent-sweep --json` on demand when investigating incomplete runs.
- Periodically synthesize repeated feedback into durable rules, skills, linters, docs, or commands.
- Run false-confidence audits after test infrastructure changes and investigate skips, vacuous assertions, over-mocking, and tests that never reach production behavior.
