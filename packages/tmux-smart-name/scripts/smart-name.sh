#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$(cd "$CURRENT_DIR/.." && pwd)/dist"
MAIN="$DIST_DIR/index.js"

case "${1:-}" in
  --run)
    node "$MAIN" >/dev/null 2>&1 || true ;;
  --menu)
    node "$MAIN" --menu 2>/dev/null || true ;;
  --status)
    node "$MAIN" --status 2>/dev/null || true ;;
  --check-attention)
    node "$MAIN" --check-attention 2>/dev/null || true ;;
  --refresh-hooks)
    CURRENT_SCRIPT_PATH="$CURRENT_DIR/smart-name.sh"
    STORED_PATH=$(tmux show-environment -g TMUX_SMART_NAME_SCRIPT_PATH 2>/dev/null | cut -d= -f2- || echo "")

    if [[ "$STORED_PATH" != "$CURRENT_SCRIPT_PATH" ]]; then
      tmux set-environment -g TMUX_SMART_NAME_SCRIPT_PATH "$CURRENT_SCRIPT_PATH"
      tmux set-hook -g after-new-window[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
      tmux set-hook -g after-select-window[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
      tmux set-hook -g after-split-window[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
      tmux set-hook -g pane-focus-in[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
      tmux set-hook -g window-layout-changed[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
      tmux set-hook -g client-attached[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --refresh-hooks\""
      tmux bind-key A run-shell "$CURRENT_DIR/smart-name.sh --menu"
      tmux set-environment -g TMUX_SMART_NAME_MENU_CMD "$CURRENT_DIR/smart-name.sh --menu"
      tmux set-environment -g TMUX_SMART_NAME_STATUS_CMD "$CURRENT_DIR/smart-name.sh --status"
      tmux display-message "tmux-smart-name: hooks updated to new version"
    fi
    ;;
  "")
    # ── Init (no args) ──────────────────────────────────────────────────
    tmux set -g automatic-rename off

    CURRENT_SCRIPT_PATH="$CURRENT_DIR/smart-name.sh"
    tmux set-environment -g TMUX_SMART_NAME_SCRIPT_PATH "$CURRENT_SCRIPT_PATH"

    # Hook array index [0] for smart-name, theme uses [100]
    tmux set-hook -g after-new-window[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
    tmux set-hook -g after-select-window[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
    tmux set-hook -g after-split-window[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
    tmux set-hook -g pane-focus-in[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
    tmux set-hook -g window-layout-changed[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
    tmux set-hook -g client-attached[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --refresh-hooks\""

    tmux set-environment -g TMUX_WINDOW_NAME_SCRIPT "$CURRENT_DIR/smart-name.sh --run"
    tmux bind-key A run-shell "$CURRENT_DIR/smart-name.sh --menu"

    tmux set-environment -g TMUX_SMART_NAME_MENU_CMD "$CURRENT_DIR/smart-name.sh --menu"
    tmux set-environment -g TMUX_SMART_NAME_STATUS_CMD "$CURRENT_DIR/smart-name.sh --status"
    tmux set-environment -g TMUX_SMART_NAME_ATTENTION_CMD "$CURRENT_DIR/smart-name.sh --check-attention"

    "$CURRENT_DIR/smart-name.sh" --run
    ;;
esac
