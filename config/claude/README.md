# Claude Configuration

This directory contains custom slash commands, agents, and configurations for Claude Code to enhance productivity and provide specialized assistance.

## Directory Structure

```
config/claude/
├── README.md           # This file
├── agents/            # Specialized agent configurations
├── commands/          # Slash commands organized by tool/workflow
│   ├── docs/         # Documentation workflow commands
│   ├── git/          # Git operations (worktree, rebase, bisect)
│   ├── jj/           # Jujutsu version control commands
│   └── nf/           # Nextflow pipeline commands
└── slash_commands/    # Task management commands
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
allowed-tools: Tool1, Tool2  # Tools Claude can use
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
