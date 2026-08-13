---
purpose: Route changes to shared agent skills, modes, and rules.
applies_to: Changes under config/agents or shared runtime deployment.
entrypoint: Use the quick reference, then the nearest subsystem guide.
verification: Run the affected agent check and hey check.
update_when: Shared agent ownership, targets, or workflows change.
---

# Agents Configuration - AI Context

Unified skills, modes, and rules for Codex, Claude, OpenCode, Pi, and Hermes agents.

## Quick Reference

- **Generated skills**: `skills/catalog/` → per-agent targets
- **Skills sync workflow**: see `skills/AGENTS.md` (commit+push skill edits first, then run `hey skills-sync`, then commit+push lockfile updates)
- **Dot-agents target**: `~/.agents/skills` for shared defaults read by Codex, Pi, OpenCode, and Hermes
- **Agent targets**: `~/.codex/skills`, `~/.pi/agent/skills`, `~/.config/opencode/skills`, `~/.hermes/skills`
- **Install gating**: target dirs are synced only when the matching local agent module is enabled; `~/.claude/skills` is intentionally removed
- **Project-local skills**: `.agents/skills/` (dotfiles-only; never global)
- **Modes**: `config/agents/modes/` → `~/.claude/agents`, `~/.config/opencode/agent`
- **Thin core**: `config/agents/core.md` → OMP startup instructions during the
  ADR 0010 pilot; maximum 250 words
- **Rules**: `config/agents/rules/` → Concatenated into Codex, Claude, and Pi instructions; symlinked to OpenCode rules

## Key Facts

- Skills use skills.sh format (YAML frontmatter + markdown)
- OMP uses the thin core plus conditional rules under `config/omp/rules/`; it
  does not consume the concatenated legacy bundle.
- Rules are numbered (01-, 02-, etc.) for ordered concatenation
- Skills default only to `dot-agents`; other agent dirs are for target-specific skills.
- Target-specific skills set `meta.targets` in `programs.dotfiles-agent-skills.targetedExplicit`.
- OpenClaw skills live separately in `~/.openclaw/skills/`

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

- `modules/agents/claude/default.nix` - Concatenates rules → CLAUDE.md
- `modules/agents/codex/default.nix` - Concatenates rules → AGENTS.md
- `modules/agents/omp/default.nix` - Installs the thin core and OMP TTSR rules
- `modules/agents/opencode/default.nix` - Symlinks all directories
- `modules/agents/pi/default.nix` - Symlinks Pi config; global skills come from agent-skills-nix
- `modules/agents/plannotator/default.nix` - Installs Plannotator integrations
