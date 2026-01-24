# tmux-opencode-integrated

Smart tmux window naming with OpenCode/Claude agent status integration.

## Features

### Status Icons

Shows status icons in window names for AI agents (opencode, claude):

| Icon | Status | Description |
|------|--------|-------------|
| `●` | Busy | Agent is running (thinking, searching, writing) |
| `■` | Waiting | Agent needs approval (permission prompts) |
| `□` | Idle | Agent is ready for input |
| `▲` | Error | Agent encountered an error (API, crash, timeout) |
| `◇` | Unknown | Could not determine status (capture failed) |

### Agent Management Panel

Press `<prefix> A` to open the Agent Management Panel popup. Like [Warp's Agent Management](https://docs.warp.dev/agents/using-agents/managing-agents), it shows:

- All agents across all sessions/windows
- Status icon, program name, session:window, path
- Agents needing attention appear first (sorted by priority)
- Press number key (1-9) to jump directly to that agent's pane

### Multi-Agent Awareness

- Tracks agents across ALL tmux panes/sessions
- Window names show aggregate status when agent is in background pane
- Priority ordering: ERROR > UNKNOWN > WAITING > BUSY > IDLE

### Status Bar Integration

Use `--status` flag to get global status for tmux status bar:

```bash
# In tmux.conf status-right:
#(smart-name.sh --status)
```

## Usage

| Command | Description |
|---------|-------------|
| `<prefix> A` | Open Agent Management Panel |
| `smart-name.sh --status` | Print global status (for status bar) |
| `smart-name.sh --menu` | Open agent panel directly |

## Installation

Managed via nix-darwin. See `modules/shell/tmux.nix`.

## Files

- `scripts/smart_name.py` - Main logic for window naming, status detection, and menu generation
- `scripts/smart-name.sh` - Shell wrapper with tmux hooks and keybinds
