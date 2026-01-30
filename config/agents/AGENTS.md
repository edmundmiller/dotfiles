# Agents Configuration - AI Context

Unified skills, modes, and rules for Claude, OpenCode, and Pi agents.

## Quick Reference

- **Skills**: `config/agents/skills/` → `~/.claude/skills`, `~/.config/opencode/skill`, `~/.pi/agent/skills`
- **Modes**: `config/agents/modes/` → `~/.claude/agents`, `~/.config/opencode/agent`
- **Rules**: `config/agents/rules/` → Concatenated into `~/.claude/CLAUDE.md`, symlinked to `~/.config/opencode/rules`

## Key Facts

- Skills use skills.sh format (YAML frontmatter + markdown)
- Rules are numbered (01-, 02-, etc.) for ordered concatenation
- All agents share the same skills and modes via nix symlinks
- Global skills.sh CLI installs go to `~/.agents/skills/` (separate from dotfiles)

## Adding Skills

Create `config/agents/skills/<name>/SKILL.md` with frontmatter:

```yaml
---
name: <name>
description: When to trigger this skill
---
```

## Nix Modules

- `modules/shell/claude/default.nix` - Concatenates rules → CLAUDE.md
- `modules/shell/opencode/default.nix` - Symlinks all directories
- `modules/shell/pi/default.nix` - Symlinks skills only
