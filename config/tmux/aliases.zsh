#!/usr/bin/env zsh

alias ta='tmux attach'
alias tl='tmux ls'

if [[ -n $TMUX ]]; then # From inside tmux
  alias tf='tmux find-window'
  # Detach all other clients to this session
  alias mine='tmux detach -a'
  # Send command to other tmux window
  function tt {
    tmux send-keys -t .+ C-u && \
      tmux set-buffer "$*" && \
      tmux paste-buffer -t .+ && \
      tmux send-keys -t .+ Enter;
  }
  # Session management now handled by sesh (C-c t)
else # From outside tmux
  # Start grouped session so I can be in two different windows in one session
  function tdup { tmux new-session -t "${1:-$(tmux display-message -p '#S')}"; }
fi
