#!/usr/bin/env bash
# All sesh sources with distinct symbol+color prefixes:
#   magenta ▪ tmux sessions  (live/active)
#   yellow  ▫ config entries (configured)
#   blue    › zoxide dirs    (frecency)

SCRIPT_DIR=${TMUX_HOME:-$(dirname "$0")}

/opt/homebrew/bin/sesh list -t | awk '{printf "\033[35m▪\033[0m %s\n", $0}'
/opt/homebrew/bin/sesh list -c | awk '{printf "\033[33m▫\033[0m %s\n", $0}'
"$SCRIPT_DIR/zoxide-list.sh"  | awk '{printf "\033[34m›\033[0m %s\n", $0}'
