# Agents Configuration

Unified configuration for AI coding agents. This directory contains global skills, rules, and modes that are generated or symlinked to each agent's configuration directory.

## Directory Structure

```
config/agents/
├── skills/      # skills.sh format skills - shared across all agents
├── modes/       # Agent modes (boomerang, coder, etc.)
└── rules/       # System prompt rules - concatenated for CLAUDE.md
```

## Supported Agents

This configuration is shared across five agents with separate generated skill targets:

| Agent      | Skills Location              | Modes Location              | Rules                       |
| ---------- | ---------------------------- | --------------------------- | --------------------------- |
| dot-agents | `~/.agents/skills/`          | N/A                         | N/A                         |
| Claude     | `~/.claude/skills/`          | `~/.claude/agents/`         | `~/.claude/CLAUDE.md`       |
| Codex      | `~/.codex/skills/`           | N/A                         | `~/.codex/AGENTS.md`        |
| OpenCode   | `~/.config/opencode/skills/` | `~/.config/opencode/agent/` | `~/.config/opencode/rules/` |
| Pi         | `~/.pi/agent/skills/`        | N/A                         | `~/.pi/agent/AGENTS.md`     |
| Hermes     | `~/.hermes/skills/`          | N/A                         | `~/.hermes/SOUL.md`         |

Hermes loads external skills from `~/.hermes/skills/` via `config/hermes/config.yml`.
Generated bundles exist for every target, but activation only syncs targets whose local agent module is enabled. The `dot-agents` shared target is synced when any local agent module is enabled.

## Skills

Use two lanes only:

- `skills/catalog/` — global skills installed into generated target dirs
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

### Current Skills

- **ast-grep** - Structural code search and refactoring
- **beads** - Multi-session task tracking with dependency graphs
- **code-search** - When to use ast-grep vs ripgrep
- **find-skills** - Discover and install skills from skills.sh
- **ghostty-config** - Ghostty terminal configuration
- **jj-merge-repos** - Merge git repositories with jj
- **python-scripts** - Python scripting guidelines
- **skill-quality** - Guidelines for writing high-quality skills
- **mdream** - HTML to Markdown converter (skilld-generated, for LLM/llm.txt workflows)
- **ui-skills** - Frontend design and UI development

## Modes

Agent modes are specialized configurations for different tasks:

- **boomerang** - Orchestrator mode for complex multi-step tasks
- **coder** - Default coding assistant mode
- **code-simplifier** - Focused on simplifying existing code
- **cursor** - Cursor-style code editing
- **sem-review** - Flexible semantic diff/review mode (sem-first, expand when needed)

## Rules

Rules are concatenated to build the system prompt (`CLAUDE.md` for Claude, `AGENTS.md` for Pi, symlinked for OpenCode):

1. `01-tone-and-style.md` - Communication style
2. `02-critical-instructions.md` - File editing, output format
3. `03-version-control.md` - Worktrees, selective staging
4. `04-code-search.md` - ast-grep over text search
5. `05-testing-philosophy.md` - Spec + regression tests
6. `06-development-preferences.md` - Persistence, philosophy
7. `07-skill-locations.md` - Where to create skills
8. `08-context-efficiency.md` - Filter at the source

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

- `modules/agents/claude/default.nix` - Claude agent nix module
- `modules/agents/opencode/default.nix` - OpenCode agent nix module
- `modules/agents/pi/default.nix` - Pi agent nix module
