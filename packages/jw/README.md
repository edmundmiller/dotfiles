# jw - JJ Workspace Management

A CLI tool for managing Jujutsu (jj) workspaces, inspired by [worktrunk](https://github.com/max-sixty/worktrunk) for git worktrees.

Designed for running AI agents (Claude, OpenCode) in parallel using jj workspaces.

Uses [gum](https://github.com/charmbracelet/gum) for interactive prompts, styled output, and spinners.

## Installation

This package is installed via nix-darwin. After `hey rebuild`, `jw` will be available in your PATH.

## Quick Start

```bash
# Create and launch Claude in a new workspace
jw switch -c -x claude agent-1

# In another terminal, start another agent
jw switch -c -x opencode agent-2

# Check status of all workspaces
jw list --full

# Merge completed work
jw merge agent-1

# Clean up
jw remove agent-1
```

## Commands

| Command | Alias | Description |
|---------|-------|-------------|
| `jw switch <name>` | `jws` | Switch to existing workspace |
| `jw switch -c <name>` | `ja` | Create and switch to workspace |
| `jw switch -c -x claude <name>` | `jwc` | Create, switch, start Claude |
| `jw switch -c -x opencode <name>` | `jwo` | Create, switch, start OpenCode |
| `jw list` | `jwl` | List workspaces with status |
| `jw list --full` | | Include ahead counts |
| `jw list --json` | | Output as JSON |
| `jw select` | | Interactive workspace picker |
| `jw remove [name]` | `jwr` | Remove workspace |
| `jw merge [name]` | `jwm` | Merge workspace to trunk |
| `jw sync [name]` | | Sync workspace with trunk |

## Interactive Features

When no arguments are provided, many commands become interactive:

| Command | Interactive Behavior |
|---------|---------------------|
| `jw switch` | Fuzzy filter to select workspace |
| `jw switch -c` | Prompt for workspace name |
| `jw remove` | Select workspace to remove |
| `jw merge` | Choose rebase or squash strategy |

The `jw select` command provides a dedicated interactive workspace picker with status indicators.

## Per-Command Help

Each command has detailed help:

```bash
jw switch --help
jw merge --help
jw list --help
```

## Comparison with worktrunk (wt)

| Task | jw (jj workspaces) | wt (git worktrees) |
|------|--------------------|--------------------|
| Create + Claude | `jwc agent-1` | `wt switch -c -x claude agent-1` |
| List with status | `jwl --full` | `wt list --full` |
| Interactive pick | `jw select` | `wt select` |
| Merge to main | `jwm agent-1` | `wt merge agent-1` |
| Remove | `jwr agent-1` | `wt remove agent-1` |

## Key Differences from Git Worktrees

- **No branches needed**: jj uses changes/revisions, not branches
- **First-class conflicts**: jj handles conflicts natively
- **Undo everything**: jj operation log provides complete history
- **Simpler merging**: Just rebase onto trunk

## Configuration

Set `JW_WORKSPACE_PATH` to customize workspace locations:

```bash
# Default (sibling directories)
export JW_WORKSPACE_PATH='../{repo}--{name}'

# Inside .jj-workspaces (like workflow tool)
export JW_WORKSPACE_PATH='.jj-workspaces/{name}'
```

Supports placeholders: `{repo}`, `{name}`

## Architecture

```
packages/jw/
├── default.nix      # Nix package definition
├── README.md        # This file
├── AGENTS.md        # Agent instructions
├── jw               # Main entry point
└── lib/
    ├── common.sh    # Shared utilities (gum wrappers)
    ├── switch.sh    # Switch/create command
    ├── list.sh      # List command (styled table)
    ├── select.sh    # Interactive picker
    ├── remove.sh    # Remove command
    ├── merge.sh     # Merge command
    ├── sync.sh      # Sync command
    └── help.sh      # Help (markdown formatted)
```

## Dependencies

- `jj` (jujutsu) - version control
- `gum` (charmbracelet/gum) - interactive prompts and styling

## See Also

- [worktrunk](https://worktrunk.dev) - Git worktree management for agents
- [jj workspaces](https://martinvonz.github.io/jj/latest/working-copy/#workspaces) - Official docs
- [poucet/workflow](https://github.com/poucet/workflow) - Similar jj workflow tool
- [charmbracelet/gum](https://github.com/charmbracelet/gum) - Interactive shell utilities
