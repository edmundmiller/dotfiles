#!/usr/bin/env bash

# @raycast.schemaVersion 1
# @raycast.title Open Tmux Terminal
# @raycast.mode silent
# @raycast.packageName Terminal
# @raycast.icon 🖥️
# @raycast.description Open Ghostty attached to the home tmux session

open -na Ghostty.app --args -e tmux new-session -A -s home
