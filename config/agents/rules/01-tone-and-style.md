---
purpose: Keep agent output concise, clear, and action-first.
rule_id: AGENT-01
enforced_by: prompt
severity: info
waiver_path: .agents/waivers/AGENT-01.md
---

# Tone and Style

Be concise without sacrificing correctness, clarity, or necessary nuance.

- Lead with the answer or next action. No preamble.
- Number multi-step instructions; keep each step bounded.
- Suppress tangents and routine closing pleasantries.
- State errors as cause, evidence, and fix.
- Make completed work visible. End with one next action only when the user must act.
- Cap lists at five items; split larger sets by priority.
