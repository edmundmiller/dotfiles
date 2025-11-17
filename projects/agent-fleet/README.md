# agent-fleet

Manage parallel JJ workspaces for AI coding agents.

agent-fleet helps you run multiple AI coding agents in isolated jj workspaces. Create a workspace, launch an agent with a task description, and let it work independently. The tool tracks active workspaces, auto-creates TaskNotes in your Obsidian vault, and provides cleanup utilities.

## Features

- Create isolated JJ workspaces in `.worktrees/` directory
- Auto-launch agents (claude-code, etc.) with task descriptions
- Track workspace metadata via JSON state file
- Auto-create TaskNotes in Obsidian vault for tracking
- List active workspaces with status
- Clean up individual or all workspaces

## Installation

### Global Installation (Recommended)

Install globally via uv tool:

```bash
uv tool install projects/agent-fleet
```

This makes `agent-fleet` available system-wide.

### Development Installation

For development, clone the dotfiles repo and use:

```bash
cd projects/agent-fleet
uv sync          # Create .venv and install dependencies
uv run agent-fleet --help
```

### Nix Installation

If using Nix (via `packages/agent-fleet.nix`):

```bash
hey rebuild     # Installs via nix-darwin
```

## Usage

### Create Workspace and Launch Agent

```bash
agent-fleet create "implement user authentication"
```

This will:

1. Generate unique task ID (YYYYMMDD-HHMMSS)
2. Create JJ workspace at `.worktrees/agent-{task-id}`
3. Save state to `.worktrees/.agent-fleet.json`
4. Create TaskNote in `~/sync/claude-vault/00_Inbox/Agents/`
5. cd into workspace
6. Launch claude-code with the task description

Options:

- `--agent claude-code`: Specify agent command (default: claude-code)
- `--auto-accept/--no-auto-accept`: Auto-accept agent edits (default: true)

### List Active Workspaces

```bash
agent-fleet list
```

Shows table with:

- Workspace name
- Task description
- Creation timestamp
- Status (Active / Missing)

### Cleanup Workspaces

Remove specific workspace:

```bash
agent-fleet cleanup agent-20250116-120000
```

Remove all workspaces:

```bash
agent-fleet cleanup --all
```

Options:

- `--force, -f`: Skip confirmation prompt

### Future Commands

```bash
agent-fleet diff <workspace-name>    # Show workspace diff (coming soon)
agent-fleet note <workspace-name>    # Manage TaskNotes (coming soon)
```

## Architecture

```
projects/agent-fleet/
├── src/agent_fleet/
│   ├── cli.py              # Main entry point
│   ├── core/              # Core functionality
│   │   ├── config.py      # Constants and configuration
│   │   ├── state.py       # State management
│   │   ├── workspace.py   # JJ workspace operations
│   │   └── obsidian.py    # TaskNote creation
│   └── commands/          # CLI commands
│       ├── create.py
│       ├── list.py
│       ├── cleanup.py
│       ├── diff.py        # Stub
│       └── note.py        # Stub
└── tests/                 # Test suite (pytest)
    ├── test_state.py
    ├── test_config.py
    └── test_workspace.py
```

## Development

### Running Tests

```bash
cd projects/agent-fleet
uv run pytest          # Run all tests
uv run pytest -v      # Verbose output
```

All 17 tests should pass:

- 9 state management tests
- 5 configuration tests
- 3 workspace parsing tests

### Adding Commands

1. Create new file in `src/agent_fleet/commands/`
2. Define Typer app with command
3. Import and add to `cli.py`

## Requirements

- Python >= 3.12
- jj (jujutsu version control)
- typer >= 0.9.0
- rich >= 13.0.0

## License

Part of personal dotfiles. Use at your own discretion.
