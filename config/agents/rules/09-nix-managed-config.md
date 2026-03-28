---
purpose: Explain that agent config files are read-only Nix symlinks — edit sources here.
---

# Nix-Managed Agent Config

Agent config files (`~/.pi/agent/`, `~/.claude/`, `~/.config/opencode/`) are **read-only Nix store symlinks**. Don't edit them directly — edit sources in this repo then `hey re`.

| Runtime path                | Source                                    |
| --------------------------- | ----------------------------------------- |
| `~/.agents/skills/*`        | `config/agents/skills/`                   |
| `~/.pi/agent/settings.json` | `config/pi/settings.jsonc`                |
| `~/.pi/agent/AGENTS.md`     | `config/agents/rules/*.md` (concatenated) |
| `~/.pi/agent/extensions/*`  | `config/pi/extensions/*`                  |
| `~/.claude/skills`          | symlink bridge to `~/.agents/skills`      |
| `~/.claude/CLAUDE.md`       | `config/agents/rules/*.md` (concatenated) |

Pi's "Could not save settings file" warning is expected and harmless.
