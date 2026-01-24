#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$CURRENT_DIR/smart_name.py"

if [[ "${1:-}" == "--run" ]]; then
    "$PY_SCRIPT" >/dev/null 2>&1 || true
    exit 0
fi

if [[ "${1:-}" == "--menu" ]]; then
    "$PY_SCRIPT" --menu 2>/dev/null || true
    exit 0
fi

if [[ "${1:-}" == "--status" ]]; then
    "$PY_SCRIPT" --status 2>/dev/null || true
    exit 0
fi

if [[ "${1:-}" == "--refresh-hooks" ]]; then
    # Check if the stored path differs from extraInit path (nix rebuild happened)
    CURRENT_SCRIPT_PATH="$CURRENT_DIR/smart-name.sh"
    STORED_PATH=$(tmux show-environment -g TMUX_OPENCODE_SCRIPT_PATH 2>/dev/null | cut -d= -f2- || echo "")
    
    if [[ "$STORED_PATH" != "$CURRENT_SCRIPT_PATH" ]]; then
        # Path changed - update all hooks to new nix store path
        tmux set-environment -g TMUX_OPENCODE_SCRIPT_PATH "$CURRENT_SCRIPT_PATH"
        tmux set-hook -g after-new-window "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
        tmux set-hook -g after-select-window "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
        tmux set-hook -g after-split-window "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
        tmux set-hook -g pane-focus-in "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
        tmux set-hook -g window-layout-changed "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
        tmux set-hook -g client-attached "run-shell -b \"$CURRENT_DIR/smart-name.sh --refresh-hooks\""
        tmux bind-key A run-shell "$CURRENT_DIR/smart-name.sh --menu"
        tmux set-environment -g TMUX_OPENCODE_MENU_CMD "$CURRENT_DIR/smart-name.sh --menu"
        tmux set-environment -g TMUX_OPENCODE_STATUS_CMD "$CURRENT_DIR/smart-name.sh --status"
        tmux display-message "tmux-opencode-integrated: hooks updated to new version"
    fi
    exit 0
fi

# Use the Python script's shebang (which points to nix python with libtmux)
# instead of calling 'python3' from PATH (which may not have libtmux)
LIBTMUX_AVAILABLE=$(
    "$PY_SCRIPT" -c 'import importlib.util; print(importlib.util.find_spec("libtmux") is not None)'
)

if [[ "$LIBTMUX_AVAILABLE" != "True" ]]; then
    tmux display-message "ERROR: tmux-opencode-integrated - Python dependency libtmux not found"
    exit 0
fi

tmux set -g automatic-rename off

# Store the current script path so we can detect when it changes (after nix rebuild)
CURRENT_SCRIPT_PATH="$CURRENT_DIR/smart-name.sh"
STORED_PATH=$(tmux show-environment -g TMUX_OPENCODE_SCRIPT_PATH 2>/dev/null | cut -d= -f2- || echo "")

# Always update hooks if path changed (handles nix rebuild case)
if [[ "$STORED_PATH" != "$CURRENT_SCRIPT_PATH" ]]; then
    tmux set-environment -g TMUX_OPENCODE_SCRIPT_PATH "$CURRENT_SCRIPT_PATH"
fi

tmux set-hook -g after-new-window "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
tmux set-hook -g after-select-window "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
tmux set-hook -g after-split-window "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
tmux set-hook -g pane-focus-in "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
tmux set-hook -g window-layout-changed "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""

# Re-run hooks setup on client attach (picks up new nix store path after rebuild)
tmux set-hook -g client-attached "run-shell -b \"$CURRENT_DIR/smart-name.sh --refresh-hooks\""

tmux set-environment -g TMUX_WINDOW_NAME_SCRIPT "$CURRENT_DIR/smart-name.sh --run"

# Bind prefix-A to open the agent management panel
tmux bind-key A run-shell "$CURRENT_DIR/smart-name.sh --menu"

# Store command paths for status bar integration
tmux set-environment -g TMUX_OPENCODE_MENU_CMD "$CURRENT_DIR/smart-name.sh --menu"
tmux set-environment -g TMUX_OPENCODE_STATUS_CMD "$CURRENT_DIR/smart-name.sh --status"
tmux set-environment -g TMUX_OPENCODE_ATTENTION_CMD "$CURRENT_DIR/smart-name.sh --check-attention"

"$CURRENT_DIR/smart-name.sh" --run
