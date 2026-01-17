#!/usr/bin/env bash
# Smart launcher for git TUIs based on VCS type
# Used by tmux popup binding (prefix + g)
# Note: Popup's -d flag sets working directory, so we check "."

# Detect VCS type (priority: jj > git > fallback)
if [ -d ".jj" ]; then
    exec jjui
elif [ -d ".git" ] || git rev-parse --git-dir >/dev/null 2>&1; then
    exec gitu
else
    # Fallback to gitu if no VCS detected
    exec gitu
fi
