# Taskwarrior aliases for zsh

# Task shell with readline support
# From: https://news.ycombinator.com/item?id=3482583
# Note: `task shell` was removed in Taskwarrior 3.x and moved to separate `tasksh` package
alias tsh='rlwrap -i -r -C tasksh tasksh'

# Taskwarrior TUI
alias tt="taskwarrior-tui"
