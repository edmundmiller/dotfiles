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

if [[ "${1:-}" == "--check-attention" ]]; then
    "$PY_SCRIPT" --check-attention 2>/dev/null || true
    exit 0
fi

if [[ "${1:-}" == "--refresh-hooks" ]]; then
    CURRENT_SCRIPT_PATH="$CURRENT_DIR/smart-name.sh"
    STORED_PATH=$(tmux show-environment -g TMUX_OPENCODE_SCRIPT_PATH 2>/dev/null | cut -d= -f2- || echo "")

    if [[ "$STORED_PATH" != "$CURRENT_SCRIPT_PATH" ]]; then
        tmux set-environment -g TMUX_OPENCODE_SCRIPT_PATH "$CURRENT_SCRIPT_PATH"
        tmux set-hook -g after-new-window[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
        tmux set-hook -g after-select-window[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
        tmux set-hook -g after-split-window[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
        tmux set-hook -g pane-focus-in[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
        tmux set-hook -g window-layout-changed[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
        tmux set-hook -g client-attached[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --refresh-hooks\""
        tmux bind-key A run-shell "$CURRENT_DIR/smart-name.sh --menu"
        tmux set-environment -g TMUX_OPENCODE_MENU_CMD "$CURRENT_DIR/smart-name.sh --menu"
        tmux set-environment -g TMUX_OPENCODE_STATUS_CMD "$CURRENT_DIR/smart-name.sh --status"
        tmux display-message "tmux-opencode-integrated: hooks updated to new version"
    fi
    exit 0
fi

# ── Init (no args) ──────────────────────────────────────────────────────────

tmux set -g automatic-rename off

# Store script path for refresh-hooks to detect nix rebuilds
CURRENT_SCRIPT_PATH="$CURRENT_DIR/smart-name.sh"
tmux set-environment -g TMUX_OPENCODE_SCRIPT_PATH "$CURRENT_SCRIPT_PATH"

# Use array index [0] for smart-name hooks (theme uses [100])
tmux set-hook -g after-new-window[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
tmux set-hook -g after-select-window[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
tmux set-hook -g after-split-window[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
tmux set-hook -g pane-focus-in[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
tmux set-hook -g window-layout-changed[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""

# Re-run hooks setup on client attach (picks up new nix store path after rebuild)
tmux set-hook -g client-attached[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --refresh-hooks\""

tmux set-environment -g TMUX_WINDOW_NAME_SCRIPT "$CURRENT_DIR/smart-name.sh --run"

# Bind prefix-A to open the agent management panel
tmux bind-key A run-shell "$CURRENT_DIR/smart-name.sh --menu"

# Store command paths for status bar integration
tmux set-environment -g TMUX_OPENCODE_MENU_CMD "$CURRENT_DIR/smart-name.sh --menu"
tmux set-environment -g TMUX_OPENCODE_STATUS_CMD "$CURRENT_DIR/smart-name.sh --status"
tmux set-environment -g TMUX_OPENCODE_ATTENTION_CMD "$CURRENT_DIR/smart-name.sh --check-attention"

"$CURRENT_DIR/smart-name.sh" --run
