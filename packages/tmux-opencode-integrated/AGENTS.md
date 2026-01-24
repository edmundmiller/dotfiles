# tmux-opencode-integrated

## Purpose

Provides tmux integration for AI coding agents (OpenCode, Claude) with smart window naming, status indicators, and an agent management panel (like Warp).

## Key Features

- **Window naming**: Auto-rename windows with status icons and program/path
- **Agent Management Panel**: `<prefix> A` opens popup showing all agents, jump to any pane
- **Global status**: `--status` flag for status bar integration
- **Priority sorting**: ERROR > UNKNOWN > WAITING > BUSY > IDLE

## Files

- `scripts/smart_name.py` - Window naming + status detection + menu generation
- `scripts/smart-name.sh` - Shell wrapper with tmux hooks and keybinds
- `default.nix` - Nix package definition

## Status Icons

| Icon | Status |
|------|--------|
| `●` | In progress (Thinking..., spinners) |
| `■` | Needs attention (Allow once?, approval prompts) |
| `□` | Idle (default) |
| `▲` | Error (Traceback, API errors, panic) |
| `◇` | Unknown (empty content, capture failed) |

## Key Functions

- `get_opencode_status(pane)` - Capture last 20 lines, pattern-match status
- `find_agent_panes(window)` - Find panes running opencode/claude
- `get_aggregate_agent_status(window)` - Highest priority status for window
- `get_global_agent_status(server)` - Scan ALL sessions/windows
- `get_all_agents_info(server)` - Detailed info for all agents (for menu)
- `run_menu()` - Execute tmux display-menu for Agent Management Panel

## CLI Usage

```bash
smart_name.py              # Run window renaming (called by hooks)
smart_name.py --status     # Print global status for status bar
smart_name.py --menu       # Open Agent Management Panel
```

## Keybinds

- `<prefix> A` - Open Agent Management Panel

## TODO

1. Integrate `#{opencode_status}` tmux format string for status bar
2. Add "Stop agent" action to menu
