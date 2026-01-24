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
| `●` | In progress (Thinking..., spinners, tool calls) |
| `■` | Needs attention (Allow once?, Permission required, approval prompts) |
| `□` | Idle - agent ready for input (prompt visible, "Done.", context display) |
| `▲` | Error (Traceback, API errors, panic) |
| `◇` | Unknown (no patterns matched, empty content, capture failed) |

**Note:** Idle is now positively detected (not just a fallback). Unknown (◇) appears when no patterns match.

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

## Troubleshooting

### Hooks not updated after `hey rebuild`

**Symptom:** Status icons don't change, menu shows wrong statuses, hooks point to old nix store path.

**Cause:** `run-shell` in tmux.conf doesn't update hooks the same way as running the script directly. The hooks set by the old version persist in the running tmux server.

**Auto-fix:** The `client-attached` hook runs `--refresh-hooks` which detects path changes and updates hooks automatically. Just detach and reattach to tmux after rebuild.

**Manual fix (if auto-fix fails):**
```bash
# Option 1: Run the script directly (find path in extraInit)
grep tmux-opencode-integrated ~/.config/tmux/extraInit
# Then run that path directly:
/nix/store/xxx-tmux-opencode-integrated-0.1.0/.../smart-name.sh

# Option 2: Restart tmux entirely
tmux kill-server && tmux
```

**Verify hooks are updated:**
```bash
tmux show-hooks -g | grep smart-name
# Should show the same nix store path as in extraInit
```

## TODO

1. Integrate `#{opencode_status}` tmux format string for status bar
2. Add "Stop agent" action to menu
3. ~~Fix hook persistence issue~~ DONE: `client-attached` hook with `--refresh-hooks`
