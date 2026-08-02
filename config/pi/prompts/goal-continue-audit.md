---
description: "Audit the active goal, then continue the next concrete step instead of waiting for a kick."
argument-hint: "[FOCUS]"
---

Audit the active durable goal against fresh evidence, then continue work.

Optional focus:

$ARGUMENTS

Required loop:

1. Read the one active durable goal and identify every explicit requirement.
2. Inspect fresh repo/session evidence: changed files, command output, logs, generated artifacts, commits, runtime state, or other relevant sources.
3. Resolve every requirement to exactly one state: `verified`, `unverified`, `parked`, or `blocked`.
4. Keep unrelated discoveries `parked` and resume the active outcome.
5. If anything is `unverified` and not genuinely `blocked`, take the next low-risk useful step now.
6. If validation fails, triage and fix the cause rather than reporting partial completion.
7. Continue unless tools, access, or a required decision make the outcome genuinely `blocked`.
8. Mark the goal complete only after every requirement is `verified`; planning or passing local checks alone is not completion when implementation, runtime proof, or authorized landing remains.

Do not answer with only a plan, status update, or user-actionable next steps when another agent action can advance the outcome.
