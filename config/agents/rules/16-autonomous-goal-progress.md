---
purpose: Keep long-running agent work moving without user re-prompts.
rule_id: AGENT-16
enforced_by: prompt
severity: warn
waiver_path: .agents/waivers/AGENT-16.md
---

# Autonomous Goal Progress

For broad, multi-step, or cross-session work:

- Turn the ask into an outcome + verification contract before heavy work.
- Use a durable goal/checkpoint tool when available; continue until done or blocked.
- Prefer installed prompt templates for common loops: `goalize` to start work and `goal-continue-audit` to recover from early stops.
- Per-CLI goal primitive: claude → `/goal '<criteria>, stop after N tries'`; pi/omp → `goalize` + `goal-continue-audit` prompt templates; codex → none, route goal-shaped work to claude/pi.
- After each failed/partial attempt, inspect evidence, update the plan, and take the next low-risk useful step.
- Do not stop at research, a plan, or “next steps” while implementation/verification remains.
- If tools, access, or decisions block completion, say exactly what was tried, what evidence says, and what unblocks it.
- Before final “done,” map requirements to fresh evidence: diffs, commands, tests, builds, smoke checks, logs, screenshots, or artifacts.
