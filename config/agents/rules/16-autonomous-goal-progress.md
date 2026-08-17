---
purpose: Keep long-running agent work moving without user re-prompts.
rule_id: AGENT-16
enforced_by: prompt
severity: warn
waiver_path: .agents/waivers/AGENT-16.md
---

# Autonomous Goal Progress

For broad, multi-step, or cross-session work, keep exactly one active outcome.

Before heavy work, make this intake contract explicit:

- `Outcome`: the single requested end state.
- `Done when`: the observable stopping condition.
- `Proof`: the commands, diffs, runtime checks, logs, screenshots, or artifacts that establish it.

Derive repository facts with tools. Request only missing product intent or authority that cannot be inferred safely. Use the existing durable goal/checkpoint tool when available; do not create a second goal-tracking convention.

- Prefer installed prompt templates for common loops: `goalize` to start work and `goal-continue-audit` to recover from early stops.
- After each failed or partial attempt, inspect evidence, update the plan, and take the next low-risk useful step.
- For delegated work, the primary must wait for each worker and continue `CONTINUE` or `PARTIAL` results until the active outcome is landed or genuinely blocked. Require each worker to return one structured return envelope with `status`, `changed_paths`, `verification`, `landing_state`, and `next_action`.
- Durable goals are checkpoints, not wake schedulers: an active goal does not relaunch a stopped worker. Keep the primary session live, or re-dispatch from fresh evidence when the runtime supports it.
- Record unrelated discoveries as `Parked`, do not pursue them, and resume the active outcome. Before proposing scope expansion, name what current work it would displace.
- Treat repeated auth, quota, or provider-limit failures as blockers after one retry: switch to an available fallback model/provider or stop with the exact blocker; do not loop on the same failing route.
- Before declaring authentication blocked, inspect canonical configured credential references and available authenticated recovery tools without exposing secret values.
- Do not stop at research, a plan, or “next steps” while implementation or verification remains.
- Keep blocked checkpoint items open. Do not mark or delete them as complete to silence reminders.
- Keep the goal open through `done`; a worker `DONE` report or passing local checks is not landing proof. Close it only after `landing_state = LANDED` or a genuine `BLOCKED` outcome with the exact unmet requirement.
- Return `Blocked` only when tools, access, or a required decision make completion impossible. State what was tried, the evidence, unmet requirements, and the smallest action that unblocks work.
- After a live tail or stream ends, always emit a nonempty synthesis that distinguishes verified current state from stale or unverified input.
- Before final `done`, map every requirement to fresh evidence. For repository work authorized to land, invoke the existing `done` skill; a clean feature worktree or passing local checks alone is not completion.
