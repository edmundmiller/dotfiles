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
| `✓` | Completed successfully |
| `■` | Needs attention (waiting for input/approval) |
| `□` | Manually stopped, idle |
| `▲` | Error occurred |

## Files

- `scripts/smart_name.py` - Window naming + status detection logic
- `scripts/smart-name.sh` - Shell wrapper called by tmux
- `default.nix` - Nix package definition

## Status Detection

`get_opencode_status()` captures pane content and pattern-matches:
- Error patterns → `▲`
- Approval prompts (`[Y/n]`, `Allow once`) → `■` waiting
- Thinking/Running patterns → `●` in progress
- Default → `□` idle

## TODO

1. Add `get_global_agent_status()` scanning all panes
2. Expose `#{opencode_status}` format string for status bar
3. Consider tmux popup for agent management panel
