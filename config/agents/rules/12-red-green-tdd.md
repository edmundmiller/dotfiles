---
purpose: Default to red/green/refactor TDD for all behavior changes.
rule_id: AGENT-12
enforced_by: prompt
severity: warn
waiver_path: .agents/waivers/AGENT-12.md
---

# Red/Green TDD

- Default to Red/Green/Refactor for behavior changes.
- For bug fixes, follow the two-commit regression flow in **Testing Philosophy**.
- Prefer concrete behavior tests over speculative coverage.
