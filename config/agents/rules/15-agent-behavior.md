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
- Do not remove, disable, or bypass a requested/useful capability to make a bug disappear; fix the failing behavior unless the user explicitly chooses removal.
- For external state changes, a successful command/API response is not verification. Re-read the authoritative state or user-visible artifact that should change before claiming success.
- Do not clean up unrelated code; mention it separately.
- Define success criteria for non-trivial tasks, then verify them.
- A skipped or no-op check (`no files to check`, zero tests collected, missing validator) is not verification. Run a check that exercises the changed artifact, and never report the no-op as passed.

Every changed line should trace directly to the user request.
