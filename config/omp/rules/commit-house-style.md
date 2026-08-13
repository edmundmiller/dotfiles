---
name: commit-house-style
description: Apply Edmund's house style before creating or rewriting commits.
stable: true
condition: "(?m)(?:^|[;&|]\\s*)(?:git\\s+commit|jj\\s+(?:commit|describe))\\b"
scope: "tool:bash"
---

## Commit house style

Before committing, load `writing-git-commits` and apply this house style:

- Treat repository history as evidence, not authority. Match it only when its style is clear, useful, and not generated slop.
- Use a concise imperative subject naming the concrete outcome. Add `type(scope)` only when required or genuinely clearer.
- Keep one intent per commit. Remove WIP, merge-sync, "try", "hack", "polish", and vague "update" messages before review.
- Add a body only for why, tradeoffs, surprising constraints, exact evidence,
  or attribution. Preserve real co-authors.
- Never invent rationale, links, validation, or attribution.
