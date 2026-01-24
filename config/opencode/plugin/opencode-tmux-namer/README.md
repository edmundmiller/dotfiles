# opencode-tmux-namer

Dynamic tmux window naming for [OpenCode](https://opencode.ai).

Automatically renames your tmux windows based on what you're working on — project name, task type (feat, fix, debug, etc.), contextual tags, and agent status.

## Features

- **Automatic naming**: Windows named like `● myproject-feat-auth` or `□ api-debug-cache`
- **Status icons**: Real-time agent status (●=busy, □=idle, ■=waiting, ▲=error)
- **AGENTS.md aware**: Reads project-specific naming conventions
- **Non-blocking**: Fire-and-forget design never slows down your workflow
- **Stability-first**: Debouncing and cooldowns prevent name thrashing

## Installation

Add to your `~/.config/opencode/opencode.json`:

```json
{
  "plugin": [
    "./plugin/opencode-tmux-namer"
  ]
}
```

Or install from npm (when published):

```json
{
  "plugin": [
    "opencode-tmux-namer@latest"
  ]
}
```

## Configuration

All configuration is via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENCODE_TMUX_DEBUG` | `0` | Set to `1` for debug logging |
| `OPENCODE_TMUX_COOLDOWN_MS` | `300000` | Minimum ms between renames (5 min) |
| `OPENCODE_TMUX_DEBOUNCE_MS` | `5000` | Debounce interval for checks (5 sec) |
| `OPENCODE_TMUX_MAX_SIGNALS` | `25` | Max activity signals to retain |
| `OPENCODE_TMUX_USE_AGENTS_MD` | `1` | Set to `0` to disable AGENTS.md reading |
| `OPENCODE_TMUX_SHOW_STATUS` | `1` | Set to `0` to disable status icons |

## Status Icons

| Icon | Status | Description |
|------|--------|-------------|
| `●` | Busy | Agent is working (streaming, running tools) |
| `□` | Idle | Agent ready for input |
| `■` | Waiting | Permission prompt, needs user action |
| `▲` | Error | Something went wrong |
| `◇` | Unknown | Unable to determine status |

## Naming Format

`[status] project-intent[-tag]`

- **status**: Icon indicating agent state
- **project**: From package.json, git repo, or directory (max 20 chars)
- **intent**: One of `feat`, `fix`, `debug`, `refactor`, `test`, `doc`, `ops`, `review`, `spike`
- **tag**: Optional context like `auth`, `api`, `cache`, `nf`, `nix` (max 15 chars)

### Examples

| Activity | Generated Name |
|----------|----------------|
| Working on new feature | `● myapp-feat` |
| Debugging auth issues | `● myapp-debug-auth` |
| Agent waiting for permission | `■ api-feat-db` |
| Agent idle, ready for input | `□ backend-refactor` |

## Trigger Events

The plugin listens to these OpenCode events:

- `session.status` — Real-time status updates (busy/idle)
- `session.idle` — After each AI turn completes
- `file.edited` — When you edit files
- `command.executed` — When you run commands
- `todo.updated` — When todos change
- `permission.updated` — When permission prompts appear

## Integration with tmux-opencode-integrated

This plugin complements the existing `tmux-opencode-integrated` package:

- **tmux-opencode-integrated**: External Python script for status detection via pane content capture
- **opencode-tmux-namer**: Native OpenCode plugin with direct event access

Use both together:
- This plugin provides accurate status from OpenCode events
- tmux-opencode-integrated provides the Agent Management Panel (`<prefix> A`)

## Development

```bash
# Type check
bun run check

# Test
bun test

# Debug mode
OPENCODE_TMUX_DEBUG=1 opencode
```

## Requirements

- [OpenCode](https://opencode.ai) v1.0+
- [tmux](https://github.com/tmux/tmux)
- Running inside a tmux session

## License

MIT
