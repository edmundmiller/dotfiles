---
purpose: Ban unsafe type assertions and enforce minimal-layer, minimal-state code.
rule_id: AGENT-10
enforced_by: prompt+lint(bin/lint-ts-architecture)
severity: warn
waiver_path: .agents/waivers/AGENT-10.md
---

# Code Standards

Two maintainability levers matter most:

1. reduce layers a reader must trace
2. reduce state a reader must hold in working memory

Enforceable policy:

- Do **not** use `as any` outside tests/fixtures.
- Prefer narrowing, typed adapters, and explicit runtime guards over broad assertions.
- If an assertion is unavoidable, keep it local and documented.
