# Skill File Locations

| Scope              | Path                                   | Notes                                          |
| ------------------ | -------------------------------------- | ---------------------------------------------- |
| Project            | `.agents/skills/<name>/SKILL.md`       | Cross-agent compatible (preferred)             |
| Global (dotfiles)  | `config/agents/skills/<name>/SKILL.md` | Installed to `~/.agents/skills/` via Nix       |
| Global (skills.sh) | `~/.agents/skills/`                    | Managed by `npx skills add`                    |
| OpenClaw           | `~/.openclaw/skills/<name>/SKILL.md`   | OpenClaw-specific; keep separate from dotfiles |

Each skill: `SKILL.md` with YAML frontmatter + optional `references/` dir.
