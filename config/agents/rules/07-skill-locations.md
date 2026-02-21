# Skill File Locations

| Scope     | Path                                    | Notes                              |
| --------- | --------------------------------------- | ---------------------------------- |
| Project   | `.agents/skills/<name>/SKILL.md`        | Cross-agent compatible (preferred) |
| Project   | `.claude/skills/` / `.pi/agent/skills/` | Agent-specific                     |
| Global    | `config/agents/skills/<name>/SKILL.md`  | Symlinked to all agents            |
| skills.sh | `~/.agents/skills/`                     | Managed by `npx skills add`        |

Each skill: `SKILL.md` with YAML frontmatter + optional `references/` dir.
