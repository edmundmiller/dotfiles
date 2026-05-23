---
purpose: Prevent common agent coding failure modes: assumptions, overbuilding, and unrelated edits.
rule_id: AGENT-15
enforced_by: prompt
severity: warn
waiver_path: .agents/waivers/AGENT-15.md
---

# Agent Behavior

Before changing code:

- State blocking assumptions. If ambiguous, ask instead of guessing.
- Prefer the smallest implementation that satisfies the request.
- Do not add speculative abstractions, configuration, or future-proofing.
- Touch only files and lines required by the task.
- Do not clean up unrelated code; mention it separately.
- Define success criteria for non-trivial tasks, then verify them.

Every changed line should trace directly to the user request.
