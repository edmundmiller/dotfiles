#!/usr/bin/env bash
# Launch try with task description as initial filter
# Called from taskwarrior-tui with task UUID(s) as arguments
# TODO: Consider spawning in new tmux/kitty window in future
desc=$(task rc.verbose=nothing "$1" _unique description 2>/dev/null | head -1)
try "${desc:-}"
