# tmux-opencode-integrated

Smart tmux window naming with OpenCode/Claude agent status integration.

## Current Behavior

Shows status icons in window names when the active pane is running an AI agent:

- `●` In progress - Agent is running (thinking, searching, writing)
- `■` Waiting - Agent needs approval (permission prompts)
- `□` Idle - Agent is ready for input
- `▲` Error - Agent encountered an error (API, crash, timeout)
- `◇` Unknown - Could not determine status (capture failed)

## Desired Behavior (Warp-style)

Like [Warp's Agent Management](https://docs.warp.dev/agents/using-agents/managing-agents), we want a **global status indicator** visible at all times, not just when focused on an agent window.

### Target UX

1. **Status bar indicator** - Always-visible icon in tmux status bar showing aggregate agent state
2. **Multi-agent awareness** - Track status across ALL tmux panes/sessions, not just active window
3. **Priority-based display**:
   - `▲` Error (any agent has error)
   - `◇` Unknown (capture failed)
   - `■` Waiting (any agent needs input)
   - `●` In progress (agents working)
   - `□` Idle (all agents idle)
4. **Click/keybind to jump** - Quick navigation to agent needing attention

### Implementation Status

- ✓ `get_global_agent_status()` scans all panes across sessions
- ✓ `--status` CLI flag outputs global status for tmux status bar
- TODO: Integrate `#{opencode_status}` tmux format string
- TODO: tmux popup showing all agents like Warp's Agent Management Panel

## Installation

Managed via nix-darwin. See `modules/shell/tmux.nix`.

## Files

- `scripts/smart_name.py` - Main logic for window naming and status detection
- `scripts/smart-name.sh` - Shell wrapper
