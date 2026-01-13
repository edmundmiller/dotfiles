# Skill File Locations

When creating skills, write them to the appropriate location based on scope:

## Project Skills (Default)

For project-specific skills, use one of these locations:

| Format | Path |
|--------|------|
| **Claude-compatible** | `.claude/skills/<name>/SKILL.md` |
| **OpenCode config** | `.opencode/skill/<name>/SKILL.md` |

Both formats are valid. Use `.claude/` for compatibility with Claude Code, or `.opencode/` for OpenCode-specific projects.

## Global Skills

Only create global skills when explicitly requested. Write to:

```
~/.config/opencode/skills/<name>/SKILL.md
```

Or in this dotfiles repo:

```
config/opencode/skills/<name>/SKILL.md
```

## Skill Structure

Each skill directory should contain:

- `SKILL.md` - Main skill file with frontmatter and instructions
- `references/` - (Optional) Supporting documentation files

## Example Frontmatter

```yaml
---
name: my-skill
description: Brief description of what the skill does
triggers:
  - keyword or phrase that activates this skill
---
```

## References

- [OpenCode Skills Documentation](https://opencode.ai/docs/skills/)
