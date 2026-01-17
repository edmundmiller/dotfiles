#!/usr/bin/env bash
# Smart launcher for git TUIs based on VCS type
# Used by tmux popup binding (prefix + g)

CURRENT_PATH="$1"

# Detect VCS type (priority: jj > git > fallback)
if [ -d "$CURRENT_PATH/.jj" ]; then
    exec jjui
elif [ -d "$CURRENT_PATH/.git" ] || git -C "$CURRENT_PATH" rev-parse --git-dir >/dev/null 2>&1; then
    exec gitu
else
    # Fallback to gitu if no VCS detected
    exec gitu
fi
