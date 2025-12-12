# Claude Configuration

This directory contains custom slash commands, agents, and configurations for Claude Code to enhance productivity and provide specialized assistance.

## Plugins

Claude Code plugins provide a standardized way to package and distribute commands, agents, and configurations. This repository includes:

### Available Plugins

**[jj](plugins/jj/)** - Autonomous commit stacking and curation workflow for Jujutsu

- `/jj:commit` - Stack commits with intelligent message generation
- `/jj:split` - Split commits by pattern (test, docs, config)
- `/jj:squash` - Merge commits in the stack
- `/jj:cleanup` - Remove empty workspaces
- Includes git-to-jj command translator hook

**[json-to-toon](plugins/json-to-toon/)** - Converts JSON to TOON format for 30-60% token savings

### Plugin vs Standalone Commands

**Plugins** (in `plugins/`):

- Proper Claude Code plugin format with manifests
- Can be extracted to separate repos for sharing
- Versioned independently
- Include comprehensive documentation

**Standalone Commands** (in `commands/`):

- Original command location (kept for backward compatibility)
- Project-specific commands
- Commands still under development

Both work identically - use whichever you prefer. Plugins are recommended for mature, reusable commands.

## Directory Structure

```
config/claude/
├── README.md              # This file
├── plugins/              # Claude Code plugins
│   ├── jj/
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── commands/
│   │   └── README.md
│   ├── json-to-toon/
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   └── hooks/
│   └── git-helpers-plugin/
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── commands/
│       └── README.md
├── agents/               # Specialized agent configurations
├── commands/             # Standalone slash commands (legacy)
│   ├── git/             # Git operations
│   └── jj/              # Jujutsu commands
└── slash_commands/       # Task management commands
```

## Slash Commands

### Jujutsu (jj) Commands

Located in `commands/jj/`, these commands help Claude assist with jujutsu version control:

- **`/jj/split`** - Split mixed changes into separate commits interactively
- **`/jj/squash`** - Combine related changes into parent commits
- **`/jj/describe`** - Write and update commit descriptions with best practices
- **`/jj/undo`** - Recover from mistakes using jj's operation log
- **`/jj/rebase`** - Reorganize commits and resolve conflicts

### Git Commands

Located in `commands/git/`, for traditional git workflows:

- **`/git/worktree`** - Manage git worktrees for parallel development
- **`/git/rebase`** - Interactive rebasing and history editing
- **`/git/bisect`** - Binary search for bug introduction

### Nextflow Commands

Located in `commands/nf/`, for bioinformatics pipeline development:

- **`/nf/process`** - Create Nextflow process definitions
- **`/nf/workflow`** - Build workflow orchestration
- **`/nf/subworkflow`** - Design reusable subworkflows

### Task Management Commands

Located in `slash_commands/`:

- **`/tasks`** - View and manage Taskwarrior tasks
- **`/task-add`** - Add new tasks with proper formatting
- **`/task-done`** - Mark tasks as completed
- **`/timew`** - Time tracking with Timewarrior
- **`/timew-report`** - Generate time reports

### Documentation Commands

Located in `commands/docs/`:

- **`/docs/start-project`** - Initialize project documentation
- **`/docs/next-task`** - Get next documentation task
- **`/docs/update-task-documentation`** - Update task docs

## Command Structure

Each command file follows this structure:

```markdown
---
allowed-tools: Tool1, Tool2 # Tools Claude can use
description: Brief description of command purpose
---

## Context

- Dynamic context gathering using !`shell commands`

## Your task

Detailed instructions for Claude to follow
```

## Agents

Specialized agents in `agents/`:

- **`taskwarrior-expert`** - Advanced task management guidance
- **`timewarrior-expert`** - Time tracking expertise
- **`cursor`** - Cursor editor integration

## Usage Examples

### Working with Jujutsu and Claude

```bash
# After Claude makes multiple unrelated changes
/jj/split  # Separate changes into logical commits

# Clean up incremental work
/jj/squash  # Combine related changes

# Write proper commit messages
/jj/describe  # Get help with conventional commits

# Something went wrong
/jj/undo  # Recover using operation log
```

### Git Workflows

```bash
# Set up parallel development
/git/worktree  # Create and manage worktrees

# Clean up commit history
/git/rebase  # Interactive rebase assistance
```

## Integration with Tools

### Jujutsu + hunk.nvim

The jj commands are configured to work with hunk.nvim as the diff editor:

- Interactive splitting and squashing
- Visual diff selection
- Configured via `config/jj/config.toml`

### Task Management

Commands integrate with:

- Taskwarrior for task tracking
- Timewarrior for time logging
- Obsidian sync for note integration

## MCP Servers

```sh
claude mcp add-json -s user github '{"command":"docker","args":["run","-i","--rm","-e","GITHUB_PERSONAL_ACCESS_TOKEN","ghcr.io/github/github-mcp-server"],"env": {"GITHUB_PERSONAL_ACCESS_TOKEN":"$(op read \"op://Private/GitHub Personal Access Token/token\")"}}'
```

## Best Practices

1. **Use specific commands** - Choose the most specific command for your task
2. **Let commands gather context** - Commands auto-collect relevant information
3. **Chain operations** - Commands work well in sequence (split → describe → squash)
4. **Leverage undo** - jj's operation log makes everything reversible

## Using Plugins

### Loading Plugins

Plugins in `plugins/` are automatically discovered by Claude Code when placed in:

1. **This repository**: `config/claude/plugins/` (current location)
2. **User config**: `~/.claude/plugins/`
3. **Project-specific**: `.claude/plugins/` in any project

### Sharing Plugins

To share a plugin with the community:

1. **Extract to separate repository:**

   ```bash
   # Example: Extract jj plugin
   cd /tmp
   cp -r ~/.config/dotfiles/config/claude/plugins/jj .
   cd jj
   git init
   git add .
   git commit -m "Initial commit"
   ```

2. **Publish to GitHub:**

   ```bash
   gh repo create my-username/jj-plugin --public
   git push -u origin main
   ```

3. **Users install via:**
   ```bash
   # Clone to their plugins directory
   git clone https://github.com/my-username/jj-plugin ~/.claude/plugins/jj
   ```

### Plugin Development

When developing plugins:

- Test in `config/claude/plugins/` first (local dotfiles)
- Use `claude --debug` to verify plugin loading
- Bump version in `plugin.json` when making changes
- Document breaking changes in plugin README
- Consider extracting to separate repo when stable

## Adding New Commands

To add a new slash command:

1. Create a `.md` file in the appropriate `commands/` subdirectory
2. Add YAML frontmatter with `allowed-tools` and `description`
3. Include `## Context` section with dynamic state gathering
4. Write clear instructions in `## Your task` section
5. Provide examples and best practices

## Notes

- Commands use `!`shell commands`` in Context sections for dynamic state
- The `allowed-tools` field restricts what operations Claude can perform
- Commands are designed to be composable and work together
- All jj operations are safe due to the operation log

## Claude Code Version Issue

If slash commands aren't working, this Reddit comment mentions Claude Code v1.0.88 worked better:
https://www.reddit.com/r/ClaudeAI/comments/1ndafeq/comment/ndfazn5/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button

```bash
# Downgrade to working version
curl -O https://raw.githubusercontent.com/Homebrew/homebrew-cask/b7821349a0cd7186157cc5e2ae4e3ef1e52eddb2/Casks/c/claude-code.rb && brew install claude-code.rb

# Disable auto-updates to prevent upgrading
claude config set -g autoUpdates false
```
