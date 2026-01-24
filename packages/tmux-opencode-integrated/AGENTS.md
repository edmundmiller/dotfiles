# tmux-opencode-integrated

## Purpose

Provides tmux integration for AI coding agents (OpenCode, Claude) with smart window naming and status indicators.

## Key Gap

**Current**: Status only shown when opencode is the active window's program.

**Desired**: Global status bar indicator (like Warp) showing agent state across ALL panes/sessions. User should always know if any agent needs attention without switching windows.

## Warp Reference

See https://docs.warp.dev/agents/using-agents/managing-agents for target UX:

| Icon | Status |
|------|--------|
| `●` | In progress - agent is running |
| `■` | Needs attention (waiting for input/approval) |
| `□` | Idle - ready for input |
| `▲` | Error occurred |
| `◇` | Unknown - could not determine status |

## Files

- `scripts/smart_name.py` - Window naming + status detection logic
- `scripts/smart-name.sh` - Shell wrapper called by tmux
- `default.nix` - Nix package definition

## Status Detection

`get_opencode_status()` captures last 20 lines of pane and pattern-matches:
- Error patterns (Traceback, API errors, panic) → `▲`
- Approval prompts (Allow once?, Do you want to run) → `■` waiting
- Busy patterns (Thinking..., spinners, Working on) → `●` in progress
- Empty/capture failure → `◇` unknown
- Default → `□` idle

## Global Status

`get_global_agent_status(server)` scans ALL sessions/windows and returns:
- Highest priority status across all agents
- Total agent count
- List of agents needing attention (error/waiting/unknown)

CLI: `smart_name.py --status` outputs global status for tmux status bar.

## TODO

1. Integrate `#{opencode_status}` tmux format string
2. tmux popup for agent management panel
3. Keybind to jump to agent needing attention
