---
description: "Create or replace a durable goal and pursue it to evidence-backed completion."
argument-hint: "<TASK>"
---

Turn the request below into exactly one durable pi-codex-goal objective, create it, and start working toward completion.

Request:

$ARGUMENTS

Goal requirements:

- Use one outcome-oriented objective, not a task list.
- Include the verifiable end state, evidence surfaces, constraints, iteration policy, completion audit, and blocked stop condition.
- Do not set a token budget unless the request explicitly includes a numeric budget or limit.
- If an existing active/paused/budget-limited goal conflicts with this request, replace it.

Work requirements after creating the goal:

- Do not stop at a plan when implementation, investigation, validation, or documentation remains.
- After each failed or partial attempt, inspect fresh evidence, update the plan, and take the next low-risk useful step.
- Before saying done, map every explicit requirement to fresh evidence from files, diffs, commands, logs, tests, screenshots, generated artifacts, or commits.
- If blocked, stop without marking complete and report attempted paths, exact blockers, unmet requirements, and the smallest input/access needed to continue.
