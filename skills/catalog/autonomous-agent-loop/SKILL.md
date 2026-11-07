---
name: autonomous-agent-loop
description: Maintains goal and handoff state and diagnoses stalled agents. Use for explicit goal management, resuming recorded work, repeated nudges, or anti-ceremony/process-porn requests. Ordinary small tasks need no goal record.
---

# Autonomous agent loop

Use for explicit goal management, resuming a recorded goal, or diagnosing stalls.
Ordinary small tasks do not need a new goal record.

For anti-ceremony requests or work dominated by plans and status reports, read
[the stalled-work diagnostic](references/anti-ceremony.md), formerly
`just-say-no-to-process-porn`. Use the diagnostic without creating a goal or
tracker. Never alter tests merely to manufacture a pass; establish that a check
is wrong before correcting it. Preserve safety checks and explicitly requested
multi-stakeholder process.

## Keep one contract

Keep one active outcome in the existing request, issue, spec, or goal:

- `Outcome`: the single requested end state.
- `Done when`: the observable stopping condition.
- `Proof`: checks and evidence of that behavior on the current revision.

Derive repository facts before asking for missing intent or authority. Update
the existing record rather than creating a second tracker. When durable goal
management is requested and no record covers it, use an available goal tool;
otherwise keep the contract in the conversation. Use `goalize` and
`goal-continue-audit` when available. A goal does not grant publication or
deployment authority.

## Work loop

1. Choose the next authorized step that reduces uncertainty or advances the outcome.
2. Run it, inspect evidence, and revise the approach. Rerun affected checks after edits.
3. Keep unrelated discoveries `Parked`; do not silently expand scope.
4. Continue until the requested outcome is verified or genuinely blocked by
   access, tools, or a required decision. Do not stop at a plan, actionable next
   steps, or untriaged failures.

For background jobs, use a blocking or longest bounded wait. Increase intervals
after unchanged status; do not poll immediately without a change or near deadline.
Durable goals are checkpoints, not wake schedulers. Do not add a scheduler,
dashboard, coordinator, or notification policy to keep this loop running.

## Delegation return contract

When delegation is authorized, share the acceptance criteria and authority.
Request a compact structured report:

- `status`: `DONE`, `CONTINUE`, `PARTIAL`, or `BLOCKED`.
- `changed_paths`: every created, modified, or deleted path.
- `verification`: exact checks and evidence, including failures.
- `landing_state`: `UNLANDED`, `READY_FOR_DONE`, `LANDED`, or `BLOCKED`.
- `next_action`: next owner and concrete action, or `none`.

Include revision and checkout so the primary can inspect the actual changes.
Wait for dependent workers, inspect their evidence, and resolve `CONTINUE` or
`PARTIAL` results. A worker's `DONE` completes only its assignment. A verified
local-only request can finish `UNLANDED`; when landing is requested and authorized,
keep the goal open until landing is verified. Mark genuinely blocked work as
blocked, not done.

## Evidence-first debugging

Compare the original request, repeated follow-ups such as `continue` or `still
broken`, and the delivered evidence. Identify the missing check or unfinished
action. Patch the smallest owning instruction or tool: `AGENTS.md`, an existing
skill, a prompt template, a repo doc, or a deterministic check.

When blocked, report attempted paths, evidence, unmet criteria, the exact blocker,
and the smallest human action needed. Never call unverified, narrowed, or deferred
requirements complete.
