---
description: "Create or replace a durable goal and pursue it to evidence-backed completion."
argument-hint: "<TASK>"
---

Turn the request below into exactly one durable pi-codex-goal objective, create it, and start working toward completion.

Request:

$ARGUMENTS

Goal requirements:

- Create exactly one active goal with these fields:
  - `Outcome`: the single requested end state.
  - `Done when`: the observable stopping condition.
  - `Proof`: the commands, diffs, runtime checks, logs, screenshots, or artifacts that establish it.
- Derive repository facts; ask only for missing product intent or authority.
- Do not set a token budget unless the request explicitly includes a numeric budget or limit.
- If an existing active, paused, or budget-limited goal conflicts with this request, replace it.

Work requirements after creating the goal:

- Do not stop at a plan or local checks while implementation, investigation, validation, documentation, or authorized landing remains.
- After each failed or partial attempt, inspect fresh evidence, update the plan, and take the next low-risk useful step.
- Record unrelated discoveries as `Parked`, then resume the active outcome. Before proposing scope expansion, name what it would displace.
- Before saying done, map every explicit requirement to fresh evidence.
- If blocked, keep the goal open and report attempted paths, evidence, the exact blocker, unmet requirements, and exactly one smallest human action needed to continue.
