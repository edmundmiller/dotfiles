# tmux-opencode-status - Agent Reference

Enhanced fork of [IFAKA/tmux-opencode-status](https://github.com/IFAKA/tmux-opencode-status) with improved state detection.

## Overview

This plugin monitors OpenCode/Claude Code sessions in tmux and displays their state as icons in window names.

## States

| Icon | State    | Description                                    |
|------|----------|------------------------------------------------|
| ○    | Idle     | OpenCode open, no active session               |
| ●    | Busy     | Agent actively working (spinners, Tool:, etc.) |
| ◉    | Waiting  | Permission prompt visible                      |
| ✗    | Error    | Agent crashed (actual runtime errors only)     |
| ✔    | Finished | Agent done, prompt ready for input             |

## Enhancements Over Upstream

1. **FINISHED state (✔)**: Detects when agent completes and returns control
   - Looks for empty progress bar (`⬝⬝⬝⬝⬝⬝⬝⬝`) + status bar
   - 2-second confirmation delay to avoid false positives during animation

2. **Smarter error detection**: Only triggers on actual crashes
   - Checks for Python tracebacks, JS UnhandledPromiseRejection, FATAL ERROR
   - Does NOT trigger on error output displayed in terminal (nix build errors, etc.)
   - Key insight: If OpenCode UI elements are visible, any "error" text is just output

3. **OpenCode permission prompts**: Detects "Allow once/Allow always/Reject" dialog

4. **No color codes in window names**: Tmux format codes only work in status bar

## File Structure

```
packages/tmux-opencode-status/
├── default.nix           # Nix package (copies local files, no fetch)
├── opencode-status.tmux  # Plugin loader (from upstream)
├── opencode_status.sh    # Enhanced state detection script
├── run_tests.sh          # Test runner
├── AGENTS.md             # This file
└── tests/
    ├── test_state_detection.sh
    └── fixtures/
        ├── idle.txt
        ├── busy_spinner.txt
        ├── busy_tool.txt
        ├── waiting.txt
        ├── finished.txt
        ├── error_crash.txt
        └── false_positive_nix_error.txt
```

## Configuration

Environment variable:
- `OPENCODE_STATUS_FINISHED_DELAY`: Seconds to wait before confirming finished state (default: 2)

## Testing

Run tests:
```bash
./run_tests.sh
```

Tests mock `tmux capture-pane` using fixture files. Set `OPENCODE_STATUS_FINISHED_DELAY=0` for instant tests (done automatically by test runner).

## Key Detection Patterns

### Busy Detection
- Braille spinners: `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏`
- Circle spinners: `◐◓◑◒`
- Keywords: `thinking`, `Thinking`, `Tool:`
- Progress bar animation: `⬝.*■|■.*⬝` (mixed empty/filled)

### Waiting Detection
- Classic prompts: `[Y/n]`, `[y/N]`, `y/n`
- OpenCode dialog: `Allow once`, `Allow always`, `Reject`
- Keywords: `permission`, `approve`, `confirm`

### Finished Detection
- Empty progress bar: `⬝⬝⬝⬝⬝⬝⬝⬝` (8 empty squares)
- Session active: `esc interrupt` visible
- Status bar: `tab switch agent` or `ctrl+p commands`
- No busy indicators present

### Error Detection (strict)
- Only when OpenCode UI is NOT visible (indicates crash)
- Python: `Traceback (most recent call last`
- Node.js: `UnhandledPromiseRejection`
- Generic: `FATAL ERROR:`

## Upstream Reference

Source: https://github.com/IFAKA/tmux-opencode-status

The `opencode-status.tmux` file is fetched from upstream. The `opencode_status.sh` script is a complete rewrite with enhanced detection logic.

## Modifying This Plugin

1. Edit `opencode_status.sh` for detection logic changes
2. Add test fixtures to `tests/fixtures/` for new scenarios
3. Update `tests/test_state_detection.sh` with new test cases
4. Run `./run_tests.sh` to verify changes
5. `hey rebuild` to apply changes to tmux
