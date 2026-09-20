---
purpose: Record how standing unslop writing rules are wired in this flake.
applies_to: Agent prose, UI copy, commits, PRs, and docs.
entrypoint: Root AGENTS.md writing route, then skills/catalog/unslop/SKILL.md.
verification: python3 -m unittest tests.FAKESECRET_w2x3y4z5a6b7c8d9e0f1
update_when: The pstack pin, catalog path, or adjacent slop tools change.
---

# Unslop standing policy

maria_rcks recommended embedding Cursor pstack unslop in `AGENTS.md` so agents
do not re-read the skill every turn.

This checkout keeps the numbered rules in the global catalog skill and adds a
root `AGENTS.md` route. It does not paste the full list into `AGENTS.md` or
`config/agents/core.md`.

- [ADR 0010](../adr/0010-omp-ttsr-thin-agent-harness.md) keeps the shared
  startup core to universal invariants and a 220-word budget.
- [Agent guardrails](../agent-guardrails.md) keep `AGENTS.md` routers short.
  Longer recipes belong in skills or canonical docs.
- Catalog skills under `skills/catalog/` auto-enable globally. That is how
  flake-deployed agents receive the pinned copy.

The skill keeps upstream `disable-model-invocation: true` and
"Must always apply." Treat that metadata as the always-on contract. The root
route tells agents not to spend a turn reading the file again.

## Adjacent tools

- `deslop` reviews correct code for types, rules, and extra abstraction.
- `anti-slop` is repository Oxlint for TypeScript.
- `no-ai-slop` remains the separate petergyang skill.

## Refresh

Follow `skills/catalog/unslop/AGENTS.md`. Host deploy of the catalog still
needs `hey skills-sync` after source changes, with activation authority.
