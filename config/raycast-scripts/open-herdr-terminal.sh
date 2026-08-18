#!/usr/bin/env bash

# @raycast.schemaVersion 1
# @raycast.title Open Herdr Terminal
# @raycast.mode silent
# @raycast.packageName Terminal
# @raycast.icon 🐑
# @raycast.description Open Ghostty with Herdr as the workspace owner

open -na Ghostty.app --args -e "$HOME/.config/tmux/open-herdr.sh"
