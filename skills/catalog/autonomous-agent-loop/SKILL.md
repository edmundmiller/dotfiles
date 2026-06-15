---
name: autonomous-agent-loop
description: Use when a task is broad, multi-step, cross-session, or the user says agents need too many re-prompts/kicks, asks to use createGoal/goals, says continue/keep going, or wants rough Pi/agent sessions improved. Keeps work moving from objective to evidence-backed completion.
---

# Autonomous Agent Loop

Use this skill when the task should finish without repeated user nudges.

## Start: make the contract durable

1. Restate the requested end state as an outcome, not a task list.
2. Define concrete verification evidence before editing: commands, diffs, rendered output, smoke checks, logs, or artifact paths.
3. If a durable goal tool exists and no active goal covers the work, create one. Do not invent a token budget.
4. Inspect repo/session state before changing files; preserve unrelated user changes.

## Work loop

Repeat until done or blocked:

1. Choose the next low-risk step that reduces uncertainty or moves implementation forward.
2. Run it.
3. Inspect fresh evidence.
4. Update the plan based on what happened.
5. Continue without waiting for the user unless a decision/access blocker is real.

Do not stop at:

- a plan when implementation remains
- “next steps” the agent could do itself
- validation failures without triage
- partial completion without naming unmet requirements
- an optional ask when the original request already implied doing the work

## Evidence-first debugging

When behavior is “rough” or repeatedly needs kicks:

- Search session/log history for repeated user follow-ups: `continue`, `try again`, `did that fix`, `how is it going`, `commit`, `rerun`, `still broken`.
- Compare the first ask to the final answer: did the agent deliver artifacts and verification, or just recommendations?
- Identify missing feedback loops: no build/test, no smoke check, no rendered UI inspection, no deploy verification, no issue update.
- Patch the durable surface that future agents read: `AGENTS.md`, shared rules, skills, prompt templates, or repo docs.

## Blocked stop format

If completion is impossible, stop with:

- attempted paths
- evidence gathered
- exact blocker
- unmet requirements
- the smallest user input/access needed to continue

Never mark a durable goal complete while any requirement is unverified, narrowed, or deferred.
