---
name: oracle
description: Use Oracle to bundle prompts + files for another AI (GPT 5 Pro, etc.) when stuck, debugging, or reviewing. Also covers self-improvement — codifying learnings into agent memory and noting tool improvement ideas.
---

# Rules

## The Oracle

- Oracle bundles a prompt plus the right files so another AI (GPT 5 Pro + more) can answer. Use when stuck/bugs/reviewing.
- Run `npx -y @steipete/oracle --help` once per session before first use.

## Self-improvement

- Codify repeated corrections in the smallest durable surface that owns them:
  - reusable procedure → update an existing skill; create one only after repeat evidence
  - repository fact or convention → nearest `AGENTS.md` or canonical document
  - parseable invariant → hook, lint, test, or validator
  - truly universal scope, authority, or evidence invariant → propose a bounded
    `config/agents/core.md` change
- Do not create a second global rule bundle or put project facts in the thin core.
- Keep the active task in scope. Report a useful learning when writing it would
  require broader authority.
- Update agent memory only when the user explicitly requests a memory change.

## Tool-specific memory

- Actively think beyond the immediate task.
- When using or working near a tool the user maintains: if you notice patterns, friction, missing features, risks, or improvement opportunities, jot them down.
- Do **not** interrupt the current task to implement speculative changes.
- When note-taking is authorized, use the repository's existing idea or
  improvement location instead of creating a parallel convention:
  - `reference/ideas/<tool-name>.md` — new concepts or future directions
  - `reference/improvements/<tool-name>.md` — enhancements to existing behavior
- These notes are informal, forward-looking, and may be partial.
- Otherwise report the observation without changing files.
