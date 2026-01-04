#!/usr/bin/env bash
# tmux-opencode-status plugin

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run monitor in status-right (triggers periodic updates)
tmux set-option -ga status-right "#($PLUGIN_DIR/scripts/opencode_status.sh)"
