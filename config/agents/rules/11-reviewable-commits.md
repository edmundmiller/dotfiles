---
purpose: Keep changes split into small, reviewable commits.
rule_id: AGENT-11
enforced_by: prompt
severity: warn
waiver_path: .agents/waivers/AGENT-11.md
---

# Commit Hygiene

- One intent per commit.
- Keep commits small enough to review quickly.
- Keep each commit green (except expected-failure test commits described in Testing Philosophy).
