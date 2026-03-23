# Nix-Managed Agent Config

Agent config files (`~/.pi/agent/`, `~/.claude/`, `~/.config/opencode/`) are **read-only Nix store symlinks**. Don't edit them directly — edit sources in this repo then `hey re`.

| Runtime path                 | Source                                    |
| ---------------------------- | ----------------------------------------- |
| `~/.pi/agent/settings.json`  | `config/pi/settings.jsonc`                |
| `~/.pi/agent/AGENTS.md`      | `config/agents/rules/*.md` (concatenated) |
| `~/.pi/agent/extensions/*`   | `config/pi/extensions/*`                  |
| `~/.pi/agent/skills/*`       | `config/agents/skills/`                   |
| `~/.claude/skills/*`         | `config/agents/skills/`                   |
| `~/.config/opencode/skill/*` | `config/agents/skills/`                   |
| `~/.claude/CLAUDE.md`        | `config/agents/rules/*.md` (concatenated) |

Pi's "Could not save settings file" warning is expected and harmless.
