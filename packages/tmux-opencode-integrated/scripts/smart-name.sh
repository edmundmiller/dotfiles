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
tmux set-hook -g after-new-window "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
tmux set-hook -g after-select-window "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
tmux set-hook -g after-split-window "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
tmux set-hook -g pane-focus-in "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
tmux set-hook -g window-layout-changed "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
tmux set-environment -g TMUX_WINDOW_NAME_SCRIPT "$CURRENT_DIR/smart-name.sh --run"

# Bind prefix-A to open the agent management panel
tmux bind-key A run-shell "$CURRENT_DIR/smart-name.sh --menu"

# Store menu command path for status bar integration
tmux set-environment -g TMUX_OPENCODE_MENU_CMD "$CURRENT_DIR/smart-name.sh --menu"
tmux set-environment -g TMUX_OPENCODE_STATUS_CMD "$CURRENT_DIR/smart-name.sh --status"

"$CURRENT_DIR/smart-name.sh" --run
