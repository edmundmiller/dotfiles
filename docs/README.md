---
purpose: Index canonical repository documentation for humans and agents.
applies_to: Any task that needs architecture, workflow, or recovery context.
entrypoint: Read only the index section matching the task.
verification: Follow the linked canonical doc and run its named check.
update_when: A canonical doc is added, moved, or changes ownership.
---

# Docs

## Index

### Foundation

- [architecture.md](./architecture.md) — repo structure, module layout, hosts,
  packages, and deployment topology
- [install.md](./install.md) — bootstrap notes plus upstream nix-darwin,
  Lix, and Nix command references

### Agent references

- Root `AGENTS.md` routes tasks; the nearest nested `AGENTS.md` adds subsystem rules.
- [../AGENT_WORKFLOW.md](../AGENT_WORKFLOW.md) — canonical risk-gated workflow
- [agent-quality.md](./agent-quality.md) — generated quality capability inventory
- [../.agents/skills/nix-darwin-reference/SKILL.md](../.agents/skills/nix-darwin-reference/SKILL.md)
  — Darwin/macOS Nix workflow; keep it out of global agent prompts

### ADE / workflows

- [ade/README.md](./ade/README.md) — Agentic Development Environment docs index
- [ade/tmux-ade-spec.md](./ade/tmux-ade-spec.md) — first spec for a
  tmux-centered Agentic Development Environment
- [tmux/managing-agents.md](./tmux/managing-agents.md) — user-first tmux agent
  launch model and architecture layering

### Runbooks

- [runbooks/README.md](./runbooks/README.md) — operational runbook index

## Conventions

Follow the documentation contract in root `AGENTS.md`. Keep each doc small, linkable, and focused on one question: what exists, why it exists, how it should evolve, or how to recover.
