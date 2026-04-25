---
purpose: Ban type assertions and enforce minimal-layer, minimal-state code.
rule_id: AGENT-10
enforced_by: prompt+lint(bin/lint-ts-architecture)
severity: warn
waiver_path: .agents/waivers/AGENT-10.md
---

# Code Standards

> two things that make code actually maintainable:
>
> 1. reduce the layers a reader has to trace
> 2. reduce the state a reader has to hold in their head
>
> applies to every codebase. always.

- Never typecast. Never use `as`.
