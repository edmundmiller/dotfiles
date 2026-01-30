# Skill File Locations

When creating skills, write them to the appropriate location based on scope:

## Project Skills (Default)

For project-specific skills, create in the project's `.agents/` directory:

| Agent      | Path                               |
| ---------- | ---------------------------------- |
| All agents | `.agents/skills/<name>/SKILL.md`   |
| Claude     | `.claude/skills/<name>/SKILL.md`   |
| OpenCode   | `.opencode/skills/<name>/SKILL.md` |

Prefer `.agents/skills/` for cross-agent compatibility. Symlink to agent-specific directories if needed (see edmundmiller-dev for example).

## Global Skills (Dotfiles)

For global user-level skills in this dotfiles repo:

```
config/agents/skills/<name>/SKILL.md
```

These are symlinked to all three agents:

- `~/.claude/skills/`
- `~/.config/opencode/skill/`
- `~/.pi/agent/skills/`

## Skills.sh Ecosystem

Skills installed via `npx skills add` go to `~/.agents/skills/` (managed separately).

## Skill Structure

Each skill directory should contain:

- `SKILL.md` - Main skill file with frontmatter and instructions
- `references/` - (Optional) Supporting documentation files

## Example Frontmatter

```yaml
---
name: my-skill
description: >
  Brief description of what the skill does and when to trigger it.
  Include example phrases that should activate this skill.
license: MIT
---
```

## References

- [skills.sh Documentation](https://skills.sh/docs)
- [config/agents/README.md](../../../agents/README.md)
