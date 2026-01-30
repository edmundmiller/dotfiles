# Agents Configuration

Unified configuration for AI coding agents. This directory contains shared skills, rules, and modes that are symlinked to each agent's configuration directory.

## Directory Structure

```
config/agents/
├── skills/      # skills.sh format skills - shared across all agents
├── modes/       # Agent modes (boomerang, coder, etc.)
└── rules/       # System prompt rules - concatenated for CLAUDE.md
```

## Supported Agents

This configuration is shared across three agents:

| Agent    | Skills Location             | Modes Location              | Rules                       |
| -------- | --------------------------- | --------------------------- | --------------------------- |
| Claude   | `~/.claude/skills/`         | `~/.claude/agents/`         | `~/.claude/CLAUDE.md`       |
| OpenCode | `~/.config/opencode/skill/` | `~/.config/opencode/agent/` | `~/.config/opencode/rules/` |
| Pi       | `~/.pi/agent/skills/`       | N/A                         | `~/.pi/agent/AGENTS.md`     |

## Skills

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
- **ui-skills** - Frontend design and UI development

## Modes

Agent modes are specialized configurations for different tasks:

- **boomerang** - Orchestrator mode for complex multi-step tasks
- **coder** - Default coding assistant mode
- **code-simplifier** - Focused on simplifying existing code
- **cursor** - Cursor-style code editing

## Rules

Rules are concatenated to build the system prompt (`CLAUDE.md` for Claude, `AGENTS.md` for Pi):

1. `01-tone-and-style.md` - Communication style
2. `02-critical-instructions.md` - Important guidelines
3. `03-version-control.md` - Git/jj workflow
4. `04-code-search.md` - Search tool selection
5. `05-testing-philosophy.md` - Testing approach
6. `06-development-preferences.md` - Coding preferences
7. `07-skill-locations.md` - Where to find skills

## Adding a New Skill

1. Create a directory in `config/agents/skills/`:

   ```bash
   mkdir config/agents/skills/my-skill
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

## Related Files

- `modules/shell/claude/default.nix` - Claude agent nix module
- `modules/shell/opencode/default.nix` - OpenCode agent nix module
- `modules/shell/pi/default.nix` - Pi agent nix module
