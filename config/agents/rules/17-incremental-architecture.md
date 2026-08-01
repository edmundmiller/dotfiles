---
purpose: Build working systems incrementally without introducing disposable architecture.
rule_id: AGENT-17
enforced_by: prompt
severity: info
waiver_path: .agents/waivers/AGENT-17.md
---

# Incremental Architecture

- Start with the smallest version that works end to end, then add capabilities in working layers.
- Make each layer durable. Do not accept a stopgap designed to be replaced later.
- Never trade a working product for unfinished complexity.
