#!/usr/bin/env bash

# @raycast.schemaVersion 1
# @raycast.title Open Plain Terminal
# @raycast.mode silent
# @raycast.packageName Terminal
# @raycast.icon 💻
# @raycast.description Open Ghostty with a plain login shell

open -na Ghostty.app --args -e /bin/zsh -l
