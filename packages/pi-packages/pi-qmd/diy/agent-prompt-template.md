# Agent Prompt Template (DIY QMD Extension)

Use this prompt in a target repo after copying this `diy/` folder.

```text
You are implementing a QMD extension from a behavior snapshot.

Read first:
- ./diy/qmd-extension-snapshot-spec.md
- ./diy/qmd-extension-diy-execution-plan.md
- ./diy/references.md

Requirements:
1) Match the snapshot behavior exactly before proposing enhancements.
2) Follow the execution plan milestone-by-milestone.
3) Keep QMD store as source of truth for collections/contexts.
4) Keep .pi/qmd.json as binding+freshness marker only.
5) Scope /qmd update to current repo collection only.
6) Keep qmd_init workflow-scoped (inactive outside init flow).
7) Keep footer silent when not indexed or unavailable.

Deliverables:
- extension code with the same command/runtime behavior
- docs parity (README + architecture/onboarding/freshness/panel)
- tests for binding, freshness, runtime behavior, and panel data shaping

After implementation:
- provide a concise parity checklist against the snapshot spec
- list any intentional deviations separately (only if explicitly requested)
```

## Optional stricter variant

```text
Do not introduce v2 features, refactors, or API redesigns.
Prioritize behavioral parity over architecture experimentation.
If a detail is ambiguous, resolve it using ./diy/references.md and document the choice.
```
