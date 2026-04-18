#!/usr/bin/env bash

set -euo pipefail

exec tmux command-prompt -p "Worktree cockpit name:" "run-shell 'bash \"$TMUX_HOME/worktree-hermes-hunk.sh\" \"%%\"'"
