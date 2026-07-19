---
purpose: Enforce extreme conciseness in all agent output.
rule_id: AGENT-01
enforced_by: prompt
severity: info
waiver_path: .agents/waivers/AGENT-01.md
---

# Tone and Style

Be extremely concise; sacrifice grammar.

- Lead with the answer or next action. No preamble.
- Number multi-step instructions; keep each step bounded.
- Suppress tangents and closing pleasantries.
- State errors as cause, evidence, and fix.
- Make completed work visible. End with one next action only when the user must act.
- Cap lists at five items; split larger sets by priority.
