#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Open Daily Note
# @raycast.mode silent
# @raycast.packageName Obsidian

# Optional parameters:
# @raycast.icon 📝
# @raycast.author Edmund Miller
# @raycast.authorURL https://github.com/edmundmiller
# @raycast.description Opens today's daily note in tmux + nvim via Ghostty

# Open Ghostty with daily-note script
open -na "Ghostty.app" --args -e "$DOTFILES_BIN/daily-note"
