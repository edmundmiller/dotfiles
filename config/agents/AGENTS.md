---
purpose: Route changes to shared agent skills, modes, and thin startup context.
applies_to: Changes under config/agents or shared runtime deployment.
entrypoint: Use the quick reference, then the nearest subsystem guide.
verification: Run the affected agent check and hey check.
update_when: Shared agent ownership, targets, or workflows change.
---

# Agents Configuration - AI Context

Unified skills, modes, and startup context for Codex, Claude, OpenCode, Pi, and OMP.

## Quick Reference

- **Generated skills**: `skills/catalog/` → per-agent targets
- **Skills sync workflow**: see `skills/AGENTS.md` (commit+push skill edits first, then run `hey skills-sync`, then commit+push lockfile updates)
- **Dot-agents target**: `~/.agents/skills` for shared defaults read by Codex, Pi, OpenCode, and Hermes
- **Agent targets**: `~/.codex/skills`, `~/.pi/agent/skills`,
  `~/.config/opencode/skills` (V2 compatibility alias), `~/.hermes/skills`
- **Install gating**: target dirs are synced only when the matching local agent module is enabled; `~/.claude/skills` is intentionally removed
- **Project-local skills**: `.agents/skills/` (dotfiles-only; never global)
- **Modes**: `config/agents/modes/` → `~/.claude/agents`,
  `~/.config/opencode2/opencode/agent`
- **Thin core**: `config/agents/core.md` → Global startup instructions for OMP,
  Codex, Claude, Pi, and OpenCode; maximum 220 words

## Key Facts

- Skills use skills.sh format (YAML frontmatter + markdown)
- OMP adds conditional TTSR rules under `config/omp/rules/`; other runtimes use
  their native skills, scoped instruction files, hooks, and deterministic checks.
- OpenCode V2 discovers its global `AGENTS.md`; its legacy `instructions` array
  is not an active instruction-loading surface.
- Skills default only to `dot-agents`; other agent dirs are for target-specific skills.
- Target-specific skills set `meta.targets` in `programs.dotfiles-agent-skills.targetedExplicit`.

## Adding Skills

For global skills, create `skills/catalog/<name>/SKILL.md`.

For project-local skills that are only relevant to this dotfiles repo, create `.agents/skills/<name>/SKILL.md`; do not wire these into the global bundle.

Example frontmatter:

```yaml
---
name: <name>
description: When to trigger this skill
---
```

## Nix Modules

- `modules/agents/claude/default.nix` - Installs the thin core → CLAUDE.md
- `modules/agents/codex/default.nix` - Installs the thin core → AGENTS.md
- `modules/agents/omp/default.nix` - Installs the thin core and OMP TTSR rules
- `modules/agents/opencode/default.nix` - Installs the thin core → V2 AGENTS.md
- `modules/agents/pi/default.nix` - Installs the thin core and Pi runtime config
- `modules/agents/plannotator/default.nix` - Installs Plannotator integrations
