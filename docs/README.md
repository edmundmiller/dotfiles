# Docs

Living documentation for this dotfiles repo.

The goal of this directory is to keep **humans and agents aligned** on how the
system works, what is intentional, and where changes should land.

## Index

### Foundation

- [architecture.md](./architecture.md) — repo structure, module layout, hosts,
  packages, and deployment topology
- [install.md](./install.md) — install/bootstrap guidance

### ADE / workflows

- [ade/README.md](./ade/README.md) — Agentic Development Environment docs index
- [ade/tmux-ade-spec.md](./ade/tmux-ade-spec.md) — first spec for a
  tmux-centered Agentic Development Environment
- [tmux/managing-agents.md](./tmux/managing-agents.md) — user-first tmux agent
  launch model and architecture layering

### Runbooks

- [runbooks/README.md](./runbooks/README.md) — operational runbook index

## Conventions

- Prefer **small, linkable docs** over giant notes dumps.
- Prefer docs that answer one of these questions:
  - What exists?
  - Why does it exist?
  - How should it evolve?
  - How do we recover when it breaks?
- When a workflow becomes important enough to preserve across sessions, give it
  a doc here instead of leaving it in chat history.
