# Agents Configuration - AI Context

Unified skills, modes, and rules for Claude, OpenCode, and Pi agents.

## Quick Reference

- **Global shared skills**: `config/agents/skills/` → `~/.agents/skills`
- **Claude compatibility bridge**: `~/.claude/skills` → `~/.agents/skills`
- **Project-local skills**: `.agents/skills/`
- **Modes**: `config/agents/modes/` → `~/.claude/agents`, `~/.config/opencode/agent`
- **Rules**: `config/agents/rules/` → Concatenated into `~/.claude/CLAUDE.md` and `~/.pi/agent/AGENTS.md`, symlinked to `~/.config/opencode/rules`

## Key Facts

- Skills use skills.sh format (YAML frontmatter + markdown)
- Rules are numbered (01-, 02-, etc.) for ordered concatenation
- All agents share the same skills and modes via nix symlinks
- Pi and OpenCode discover `~/.agents/skills/` natively
- Claude uses `~/.claude/skills/`, bridged to `~/.agents/skills/`
- OpenClaw skills live separately in `~/.openclaw/skills/`

## Adding Skills

For global/shared skills, create `config/agents/skills/<name>/SKILL.md`.

For project-local skills, create `.agents/skills/<name>/SKILL.md`.

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
