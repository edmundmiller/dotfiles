---
name: autonomous-agent-loop
description: Use when a task is broad, multi-step, cross-session, or the user says agents need too many re-prompts/kicks, asks to use createGoal/goals, says continue/keep going, or wants rough Pi/agent sessions improved. Keeps work moving from objective to evidence-backed completion.
---

# Autonomous Agent Loop

Use this skill when the task should finish without repeated user nudges.

## Start: make the contract durable

Keep exactly one active outcome. Record:

- `Outcome`: the single requested end state.
- `Done when`: the observable stopping condition.
- `Proof`: the commands, diffs, rendered output, smoke checks, logs, or artifacts that establish it.

Derive repository facts before asking. Request only missing product intent or authority. If a durable goal tool exists and no active goal covers the work, create one; do not add a task store or second goal-tracking convention. Prefer `goalize` and `goal-continue-audit`, and keep project-specific details in the goal or repository docs.

## Work loop

Repeat until the only valid return state is `done` or genuine `blocked`:

1. Choose the next low-risk step that reduces uncertainty or advances the outcome.
2. Run it and inspect fresh evidence.
3. Update the plan from that evidence.
4. Record unrelated discoveries as `Parked`, then resume the active outcome.
5. Before proposing scope expansion, state what current work it would displace.
6. Continue without waiting unless tools, access, or a required decision make progress impossible.
7. For background jobs, use a blocking or longest bounded wait when available. After an unchanged status, increase the interval; never poll again immediately unless the status changed or a real deadline is near.

Do not stop at a plan, agent-actionable next steps, untriaged validation failures, or partial completion. Do not add a scheduler, dashboard, coordinator process, or notification policy; existing durable-goal tools are the execution mechanism.

## Evidence-first debugging

When behavior is “rough” or repeatedly needs kicks:

- Search session/log history for repeated user follow-ups: `continue`, `try again`, `did that fix`, `how is it going`, `commit`, `rerun`, `still broken`.
- Compare the first ask to the final answer: did the agent deliver artifacts and verification, or just recommendations?
- Identify missing feedback loops: no build/test, no smoke check, no rendered UI inspection, no deploy verification, no issue update.
- Patch the durable surface that future agents read: `AGENTS.md`, shared rules, skills, prompt templates, or repo docs.

## Blocked stop format

Return `blocked` only when completion is impossible. Report:

- attempted paths
- evidence gathered
- exact blocker
- unmet requirements
- exactly one smallest human action needed to continue

Never mark a durable goal `done` while any requirement is unverified, narrowed, deferred, or merely locally checked when authorized landing remains.
