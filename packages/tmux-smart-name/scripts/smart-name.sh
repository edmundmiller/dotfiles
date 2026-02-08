#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$(cd "$CURRENT_DIR/.." && pwd)/dist"
MAIN="$DIST_DIR/index.js"

LOCKFILE="/tmp/tmux-smart-name.lock"

case "${1:-}" in
  --run)
    # Debounce: skip if lock file exists and is <1s old (prevents hook storms)
    if [[ -f "$LOCKFILE" ]]; then
      lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCKFILE" 2>/dev/null || echo 0) ))
      if (( lock_age < 1 )); then
        exit 0
      fi
    fi
    touch "$LOCKFILE"
    node "$MAIN" >/dev/null 2>&1 || true ;;
  --menu)
    node "$MAIN" --menu 2>/dev/null || true ;;
  --status)
    node "$MAIN" --status 2>/dev/null || true ;;
  --check-attention)
    node "$MAIN" --check-attention 2>/dev/null || true ;;
  --tick)
    # Called by status-right #() every status-interval seconds.
    # Runs rename + attention check in single process, outputs nothing.
    node "$MAIN" --tick 2>/dev/null || true ;;
  --refresh-hooks)
    CURRENT_SCRIPT_PATH="$CURRENT_DIR/smart-name.sh"
    STORED_PATH=$(tmux show-environment -g TMUX_SMART_NAME_SCRIPT_PATH 2>/dev/null | cut -d= -f2- || echo "")

    if [[ "$STORED_PATH" != "$CURRENT_SCRIPT_PATH" ]]; then
      tmux set-environment -g TMUX_SMART_NAME_SCRIPT_PATH "$CURRENT_SCRIPT_PATH"
      tmux set-hook -g after-new-window[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
      tmux set-hook -g after-select-window[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
      tmux set-hook -g after-split-window[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
      tmux set-hook -g client-attached[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --refresh-hooks\""
      # Clean up old noisy hooks
      tmux set-hook -gu pane-focus-in[0] 2>/dev/null || true
      tmux set-hook -gu window-layout-changed[0] 2>/dev/null || true
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
    # Minimal hooks: new window/split need immediate naming.
    # Ongoing status updates handled by --tick via status-right #().
    # pane-focus-in and window-layout-changed removed — too noisy, cause scroll glitches.
    tmux set-hook -g after-new-window[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
    tmux set-hook -g after-select-window[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
    tmux set-hook -g after-split-window[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --run\""
    tmux set-hook -g client-attached[0] "run-shell -b \"$CURRENT_DIR/smart-name.sh --refresh-hooks\""
    # Remove noisy hooks from older versions
    tmux set-hook -gu pane-focus-in[0] 2>/dev/null || true
    tmux set-hook -gu window-layout-changed[0] 2>/dev/null || true

    tmux set-environment -g TMUX_WINDOW_NAME_SCRIPT "$CURRENT_DIR/smart-name.sh --run"
    tmux bind-key A run-shell "$CURRENT_DIR/smart-name.sh --menu"

    tmux set-environment -g TMUX_SMART_NAME_MENU_CMD "$CURRENT_DIR/smart-name.sh --menu"
    tmux set-environment -g TMUX_SMART_NAME_STATUS_CMD "$CURRENT_DIR/smart-name.sh --status"
    tmux set-environment -g TMUX_SMART_NAME_ATTENTION_CMD "$CURRENT_DIR/smart-name.sh --check-attention"

    # Periodic refresh: piggyback on status-interval (runs every N seconds).
    # Appends a hidden #() call to status-right that triggers rename + attention check.
    # The #() output is empty so it doesn't change the status bar visually.
    tmux set-option -ga status-right "#($CURRENT_DIR/smart-name.sh --tick)"

    "$CURRENT_DIR/smart-name.sh" --run
    ;;
esac
