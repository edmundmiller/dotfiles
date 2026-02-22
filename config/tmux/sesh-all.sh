#!/usr/bin/env bash
# All sesh sources with distinct symbol+color prefixes:
#   magenta ▪ tmux sessions  (live/active)
#   yellow  ▫ config entries (configured)
#   blue    › zoxide dirs    (frecency)
# Filters out the current tmux session and current pane directory.

SCRIPT_DIR=${TMUX_HOME:-$(dirname "$0")}
CURRENT_SESSION=$(tmux display-message -p '#S' 2>/dev/null)
CURRENT_DIR=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)
# Collapse $HOME to ~ for matching against zoxide/config output
CURRENT_DIR_SHORT=${CURRENT_DIR/#$HOME/\~}

/opt/homebrew/bin/sesh list -t | grep -vxF "$CURRENT_SESSION" | awk '{printf "\033[35m▪\033[0m %s\n", $0}'
/opt/homebrew/bin/sesh list -c | grep -vxF "$CURRENT_SESSION" | awk '{printf "\033[33m▫\033[0m %s\n", $0}'
"$SCRIPT_DIR/zoxide-list.sh"  | grep -vxF "$CURRENT_DIR_SHORT" | awk '{printf "\033[34m›\033[0m %s\n", $0}'
