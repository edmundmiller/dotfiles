---
purpose: Enforce boundary parsing, safe types, and minimal abstractions.
rule_id: AGENT-10
enforced_by: prompt+lint(bin/lint-ts-architecture)
severity: warn
waiver_path: .agents/waivers/AGENT-10.md
---

# Code Standards

Minimize the layers, state, and code a reader must understand.

- Do **not** use `as any` outside tests/fixtures.
- Prefer narrowing, typed adapters, and explicit runtime guards over broad assertions.
- If an assertion is unavoidable, keep it local and documented.
- Parse and validate at outer boundaries; pass typed domain values inward.
- Reuse existing repository or library primitives before adding a utility, parser, or collection helper.
- Reject duplicate, pass-through, or speculative abstractions. Every interface, parameter, and function must earn its place.
- Preserve backward compatibility only when required by documented consumers, public APIs, or migrations.
- Prefer established, well-maintained libraries when they materially reduce complexity; avoid dependencies for trivial behavior.
- Prefer the simplest correct design and the least code.
