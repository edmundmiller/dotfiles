---
purpose: Explain shared agent configuration ownership and deployment.
applies_to: Changes to shared agent skills, modes, or rules.
entrypoint: Use config/agents/AGENTS.md, then the relevant source directory.
verification: Rebuild and inspect the affected runtime path.
update_when: Supported runtimes, paths, or deployment behavior changes.
---

# Agents Configuration

Shared rules and modes for AI coding agents. Global skills live in `skills/catalog/`; validate them with `skills/catalog/skill-quality/scripts/validate.py`.

## Directory Structure

```
config/agents/
├── modes/       # Agent modes
└── rules/       # System prompt rules
```

## Supported Agents

This configuration is shared across agent runtimes with generated skill targets:

| Agent      | Skills Location              | Modes Location              | Rules                       |
| ---------- | ---------------------------- | --------------------------- | --------------------------- |
| dot-agents | `~/.agents/skills/`          | N/A                         | N/A                         |
| Claude     | N/A                          | `~/.claude/agents/`         | `~/.claude/CLAUDE.md`       |
| Codex      | `~/.codex/skills/`           | N/A                         | `~/.codex/AGENTS.md`        |
| OpenCode   | `~/.config/opencode/skills/` | `~/.config/opencode/agent/` | `~/.config/opencode/rules/` |
| Pi         | `~/.pi/agent/skills/`        | N/A                         | `~/.pi/agent/AGENTS.md`     |
| Hermes     | `~/.hermes/skills/`          | N/A                         | `~/.hermes/SOUL.md`         |

Hermes loads external skills from `~/.hermes/skills/` via `config/hermes/config.yml`.
Generated bundles exist for supported skill targets, but activation only syncs targets whose local agent module is enabled. Defaults live only in `dot-agents`; runtime-specific dirs carry targeted skills. Claude skill deployment is disabled to prevent duplicate OMP discovery.

## Skills

Use two lanes only:

- `skills/catalog/` — global skills installed into `~/.agents/skills`
- `.agents/skills/` — project-local skills checked into this repo; never install these into `~/.agents/skills/`

OpenClaw keeps its own skills in `~/.openclaw/skills/`.

Skills use the [skills.sh](https://skills.sh/docs) format with YAML frontmatter:

```markdown
---
name: skill-name
description: >
  When to trigger this skill. Include phrases that activate it.
license: MIT
---

# Skill Title

Skill content...
```

### Discover Skills

Query live sources instead of maintaining an inventory:

```bash
find skills/catalog .agents/skills skills/conditional -name SKILL.md -type f | sort
```

## Modes

Agent modes are specialized configurations for different tasks:

- **boomerang** - Orchestrator mode for complex multi-step tasks
- **coder** - Default coding assistant mode
- **code-simplifier** - Focused on simplifying existing code
- **cursor** - Cursor-style code editing
- **sem-review** - Flexible semantic diff/review mode (sem-first, expand when needed)

## Rules

Rules are concatenated for Codex, Claude, and Pi and exposed individually to OpenCode. Query their live metadata:

```bash
python3 bin/check-agent-rules --json
```

## Adding a New Skill

### Global/shared skill

1. Create a directory in `skills/catalog/`:

   ```bash
   mkdir skills/catalog/my-skill
   ```

2. Create `SKILL.md` with frontmatter:

   ```markdown
   ---
   name: my-skill
   description: Description of when to use this skill
   license: MIT
   ---

   # My Skill

   Skill content...
   ```

3. Run `hey rebuild` to deploy

### Project-local skill

1. Create a directory in `.agents/skills/`:

   ```bash
   mkdir -p .agents/skills/my-skill
   ```

2. Add `SKILL.md` with the same frontmatter shape as above.

## Related Files

Runtime ownership and deployment routes live in `modules/agents/AGENTS.md`.
