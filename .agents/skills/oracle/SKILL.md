---
name: oracle
description: Use Oracle to bundle prompts + files for another AI (GPT 5 Pro, etc.) when stuck, debugging, or reviewing. Also covers self-improvement — codifying learnings into agent memory and noting tool improvement ideas.
---

# Rules

## The Oracle

- Oracle bundles a prompt plus the right files so another AI (GPT 5 Pro + more) can answer. Use when stuck/bugs/reviewing.
- Run `npx -y @steipete/oracle --help` once per session before first use.

## Self-improvement

- Continuously improve agent workflows.
- When a repeated correction or better approach is found, codify it:
  - **Global rules** (apply to all agents/projects): add a numbered `.md` file in `~/.config/dotfiles/config/agents/rules/` (e.g. `09-<name>.md`). These get concatenated into every agent's system prompt at rebuild (`hey re`). Keep rules short (<500B) — if longer, make a skill instead.
  - **Project-specific memory** (pi only): use `memory_write` to `system/style.md`, `system/project.md`, or `reference/<topic>.md`.
- No prior approval needed for codifying learnings.
- When applying a previously codified rule in a future session, call it out and tell the user which rule triggered the behavior.
- Echo back any new learnings to the user when writing them.

## Tool-specific memory

- Actively think beyond the immediate task.
- When using or working near a tool the user maintains: if you notice patterns, friction, missing features, risks, or improvement opportunities, jot them down.
- Do **not** interrupt the current task to implement speculative changes.
- Write notes via `memory_write` (pi) or directly to files:
  - `reference/ideas/<tool-name>.md` — new concepts or future directions
  - `reference/improvements/<tool-name>.md` — enhancements to existing behavior
- These notes are informal, forward-looking, and may be partial.
- No permission needed to add or update these files.
