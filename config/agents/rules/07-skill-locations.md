---
purpose: Map where agent skill files live across project and global scopes.
rule_id: AGENT-07
enforced_by: prompt
severity: info
waiver_path: .agents/waivers/AGENT-07.md
---

# Skill File Locations

| Scope              | Path                             | Notes                                                   |
| ------------------ | -------------------------------- | ------------------------------------------------------- |
| Project (dotfiles) | `.agents/skills/<name>/SKILL.md` | Dotfiles project-local only; never install globally     |
| Global (dotfiles)  | `skills/catalog/<name>/SKILL.md` | Cross-project; installed to `~/.agents/skills/` via Nix |

Each skill: `SKILL.md` with YAML frontmatter + optional `references/` dir.

Dotfiles project-local skills must not appear in `~/.agents/skills/`. If `hey re` reports a leak, run `hey skills-cleanup-local-leaks` before rebuilding.
