---
purpose: Prevent common agent coding failure modes: assumptions, overbuilding, and unrelated edits.
rule_id: AGENT-15
enforced_by: prompt
severity: warn
waiver_path: .agents/waivers/AGENT-15.md
---

# Agent Behavior

Before changing code:

- Ask only when a decision is materially ambiguous, risky, or requires approval.
- Use relevant skills. Use Visualize when a visual materially improves an explanation. Spawn subagents only for genuinely independent work, then synthesize their findings.
- Prefer the smallest implementation that satisfies the request.
- Do not add speculative abstractions, configuration, or future-proofing.
- Touch only files and lines required by the task.
- For screenshot- or reference-driven configuration changes, compare the requested state with the current source and edit only values whose requested state differs; visible unchanged fields are context, not scope.
- Do not create a skill from a one-off diagnosis or private user/project fact. Store facts in memory; codify only a generic procedure supported by repeat evidence.
- Do not remove, disable, or bypass a requested/useful capability to make a bug disappear; fix the failing behavior unless the user explicitly chooses removal.
- Ground research in authoritative, current sources and link important evidence.
- For diagnostic or compliance questions, inspect the underlying records before proposing changes; separate verified facts, user-supplied facts, and unknowns.
- For external state changes, use any user-named interface and re-read every requested attribute from authoritative or user-visible state; a successful command/API response is not verification.
- Immediately before each external write, verify the active account, organization, project, and target identifier; abort on any mismatch.
- For non-idempotent creates, treat success as terminal: persist and re-read the returned identifier, and retry only after an unambiguous failure.
- For scheduled external changes, resolve the next fire time under the provider's timezone and weekday semantics, then re-read the deployed trigger.
- For scheduled jobs and services, verify the executable path in the deployed environment, require live scheduler, unit, or process evidence rather than leftover state files, and exercise one representative invocation before claiming activation.
- Before changing behavior for a reported bug, reproduce the reported symptom or explicitly classify it as unverified; never patch from the report alone.
- Before editing or reviewing, confirm every target path belongs to the assigned checkout and that no rebase or concurrent mutation is active; never fall back to files in another checkout.
- Do not clean up unrelated code; mention it separately.
- Define success criteria for non-trivial tasks, then verify them.
- Test observable behavior, review substantial changes, and validate user-facing work in the real interface when applicable.
- Passing automated checks alone does not prove compliance. Re-read the request and applicable instructions, then inspect the diff or artifact against them before claiming success.
- A skipped or no-op check (`no files to check`, zero tests collected, missing validator) is not verification. Run a check that exercises the changed artifact, and never report the no-op as passed.

Every changed line should trace directly to the user request.
