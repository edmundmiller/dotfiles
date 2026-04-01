#!/usr/bin/env sh

# Load opensessions from the runtime checkout synced by the tmux module.

set -eu

OPENSESSIONS_DIR="${OPENSESSIONS_DIR:-$HOME/.local/share/opensessions/current}"
PLUGIN_ENTRY="$OPENSESSIONS_DIR/opensessions.tmux"

if [ ! -f "$PLUGIN_ENTRY" ]; then
  tmux display-message "opensessions: missing $PLUGIN_ENTRY"
  exit 0
fi

# Ensure tmux server PATH includes Nix-provided runtime deps for plugin scripts.
PATH_PREFIX="$(tmux show-environment -g OPENSESSIONS_PATH_PREFIX 2>/dev/null | cut -d= -f2- || true)"
CURRENT_PATH="$(tmux show-environment -g PATH 2>/dev/null | cut -d= -f2- || true)"

if [ -n "$PATH_PREFIX" ]; then
  BASE_PATH="${CURRENT_PATH:-$PATH}"
  case ":$BASE_PATH:" in
    *":$PATH_PREFIX:"*) ;;
    *) tmux set-environment -g PATH "$PATH_PREFIX:$BASE_PATH" ;;
  esac
fi

tmux set-environment -g OPENSESSIONS_DIR "$OPENSESSIONS_DIR"

exec sh "$PLUGIN_ENTRY"
