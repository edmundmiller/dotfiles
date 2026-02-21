#!/usr/bin/env bash
# All sesh sources with colored dot prefixes:
#   cyan   • tmux sessions  (live)
#   yellow • config entries (configured)
#   green  • zoxide dirs    (frecency)

SESH=/opt/homebrew/bin/sesh
SCRIPT_DIR=${TMUX_HOME:-$(dirname "$0")}

/opt/homebrew/bin/sesh list -t | awk '{printf "\033[36m•\033[0m %s\n", $0}'
/opt/homebrew/bin/sesh list -c | awk '{printf "\033[33m•\033[0m %s\n", $0}'
"$SCRIPT_DIR/zoxide-list.sh"  | awk '{printf "\033[32m•\033[0m %s\n", $0}'
