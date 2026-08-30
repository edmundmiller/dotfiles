---
purpose: Tell engineering skills how to consume this repository's domain docs.
applies_to: Exploration, issue/spec writing, architecture, and refactoring.
entrypoint: Read CONTEXT.md and relevant docs/adr/ files before exploring.
verification: Use glossary terms and surface conflicts with applicable ADRs.
update_when: Domain doc locations, context layout, or consumer rules change.
---

# Domain docs

This is a single-context repository. Before exploring, read root `CONTEXT.md`
and any relevant ADRs under `docs/adr/`. If a referenced file is absent,
proceed without flagging its absence or creating it just for setup.

Use the glossary's vocabulary in issue titles, specs, refactor proposals, and
test names. If a needed concept is missing, note it for `/domain-modeling`.
If a proposed change conflicts with an ADR, name the ADR and surface the
conflict instead of silently overriding it.
