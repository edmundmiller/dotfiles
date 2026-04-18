# ADE Docs

This folder is the starting point for a repo-local **Agentic Development
Environment (ADE)** spec.

The intent is to create a shared source of truth for:

- human workflow decisions
- agent workflow expectations
- tmux/session conventions
- implementation priorities
- known gaps between the intended workflow and the current repo state

## Documents

- [tmux-ade-spec.md](./tmux-ade-spec.md) — primary draft spec for building a
  tmux-first ADE in this repo
- [../tmux/managing-agents.md](../tmux/managing-agents.md) — user-first
  operating model for launching/managing agent workflows in tmux

## How to use these docs

- Treat specs here as **living design docs**, not polished marketing docs.
- Prefer concrete language over aspirational fluff.
- Prefer docs that distinguish clearly between:
  - the **intended target state**
  - the **current implementation reality**
  - the **migration path** between them
- When implementing a workflow change, update the relevant ADE doc in the same
  change when practical.
- If humans or agents start repeating the same explanation in chat, that is a
  good signal that it belongs here.

## Scope

The first ADE spec deliberately starts with **tmux** because tmux is already the
closest thing this repo has to an interactive control plane:

- it is where human focus lives
- it is where agent panes already run
- it is where session context is surfaced
- it is where project/worktree boundaries can be enforced

Later docs can expand this into adjacent areas like:

- worktree orchestration
- agent routing / launcher UX
- issue tracker integration
- remote-host parity
- session metadata and state sync
