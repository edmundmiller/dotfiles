---
purpose: Explain that agent config files are read-only Nix symlinks — edit sources here.
rule_id: AGENT-09
enforced_by: prompt
severity: info
waiver_path: .agents/waivers/AGENT-09.md
---

# Nix-Managed Agent Config

Managed agent config files under `~/.codex/`, `~/.pi/agent/`, `~/.claude/`, and `~/.config/opencode/` are **read-only Nix store symlinks** unless their runtime explicitly bootstraps a writable copy. Don't edit managed targets directly — edit sources in this repo then `hey re`.

| Runtime path                | Source                                                                                          |
| --------------------------- | ----------------------------------------------------------------------------------------------- |
| `~/.agents/skills/*`        | Global skills from `skills/catalog/` plus allowed manual global skills; never `.agents/skills/` |
| `~/.codex/AGENTS.md`        | `config/agents/rules/*.md` (concatenated)                                                       |
| `~/.pi/agent/settings.json` | `config/pi/settings.jsonc`                                                                      |
| `~/.pi/agent/AGENTS.md`     | `config/agents/rules/*.md` (concatenated)                                                       |
| `~/.pi/agent/extensions/*`  | `config/pi/extensions/*`                                                                        |
| `~/.claude/CLAUDE.md`       | `config/agents/rules/*.md` (concatenated)                                                       |

Pi's "Could not save settings file" warning is expected and harmless.
