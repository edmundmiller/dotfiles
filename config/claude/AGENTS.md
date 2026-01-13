# Claude Code Configuration

> Agent-facing documentation for the Claude Code directory structure

## Directory Structure

```
config/claude/
├── plugins/          # Claude Code plugins (user-managed)
│   ├── claude-lint/  # Plugin validation on save
│   ├── github/       # PR review commands
│   └── jj/           # Jujutsu version control integration
├── AGENTS.md         # This file (directory reference)
└── settings.json     # Claude Code settings
```

## Shared Resources

**Skills and agents are shared with OpenCode:**
- Skills: `config/opencode/skill/` → symlinked to `~/.claude/skills/`
- Agents: `config/opencode/agent/` → symlinked to `~/.claude/agents/`

**Agent instructions:**
- Built dynamically from `config/opencode/rules/*.md`
- Concatenated into `~/.claude/CLAUDE.md` at system activation
- Numeric prefixes control ordering (01-, 02-, etc.)

## Key Plugins

**claude-lint** (`config/claude/plugins/claude-lint/`)
- Real-time validation of Claude Code plugins
- Runs on file save via hook
- Uses claudelint for frontmatter/structure checks

**jj** (`config/claude/plugins/jj/`)
- Jujutsu version control integration
- Commands: /jj:commit, /jj:log, /jj:diff, etc.
- Skills: commit message generation, change management

**github** (`config/claude/plugins/github/`)
- PR review commands
- Commands: /gh:pr-review, /gh:pr-review-improve

## Nix Management

Files in this directory are symlinked by `modules/shell/claude/default.nix`:
- `settings.json` → `~/.claude/settings.json`
- `config/opencode/agent/` → `~/.claude/agents/`
- `config/opencode/skill/` → `~/.claude/skills/`
- Rules concatenated → `~/.claude/CLAUDE.md`

After `hey rebuild`, symlinks update automatically. Restart Claude Code to pick up changes.

## Plugin Development

Each plugin lives in `config/claude/plugins/<name>/`:
- `.claude-plugin/plugin.json` - Metadata and schema
- `commands/` - Command files with frontmatter
- `hooks/` - Executable scripts for lifecycle events
- `skills/` - Skill files with frontmatter
- `README.md` - User documentation

See `.claudelint.toml` for validation rules.
