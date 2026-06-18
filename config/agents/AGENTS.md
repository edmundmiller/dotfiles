# Agents Configuration - AI Context

Unified skills, modes, and rules for Claude, OpenCode, and Pi agents.

## Quick Reference

- **Generated skills**: `skills/catalog/` → per-agent targets
- **Skills sync workflow**: see `skills/AGENTS.md` (commit+push skill edits first, then run `hey skills-sync`, then commit+push lockfile updates)
- **Dot-agents target**: `~/.agents/skills`
- **Agent targets**: `~/.codex/skills`, `~/.pi/agent/skills`, `~/.claude/skills`, `~/.config/opencode/skills`, `~/.hermes/skills`
- **Install gating**: target dirs are synced only when the matching local agent module is enabled
- **Project-local skills**: `.agents/skills/` (dotfiles-only; never global)
- **Modes**: `config/agents/modes/` → `~/.claude/agents`, `~/.config/opencode/agent`
- **Rules**: `config/agents/rules/` → Concatenated into `~/.claude/CLAUDE.md` and `~/.pi/agent/AGENTS.md`, symlinked to `~/.config/opencode/rules`

## Key Facts

- Skills use skills.sh format (YAML frontmatter + markdown)
- Rules are numbered (01-, 02-, etc.) for ordered concatenation
- Skills default to every generated target; activation installs only enabled local agent targets.
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
- `modules/agents/opencode/default.nix` - Symlinks all directories
- `modules/agents/pi/default.nix` - Symlinks Pi config; global skills come from agent-skills-nix
