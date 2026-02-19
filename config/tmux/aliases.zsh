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

# tml — tmux dev layout: AI tool (70%) + lazygit (30%) on top, shell (15%) on bottom
# Inspired by basecamp/omarchy
tml() {
    local current_dir="${PWD}"
    local ai_pane
    local ai="$1"

    ai_pane=$(tmux display-message -p '#{pane_id}')

    # Bottom shell pane (15%)
    tmux split-window -v -p 15 -c "$current_dir"

    # Back to top, split for lazygit (30% right) with narrow-pane config
    tmux select-pane -t "$ai_pane"
    local lg_main="$HOME/.config/lazygit/config.yml"
    local lg_tml="$HOME/.config/lazygit/tml.yml"
    tmux split-window -h -p 30 -c "$current_dir" "lazygit --use-config-file='${lg_main},${lg_tml}'"

    # Launch AI in left pane
    tmux send-keys -t "$ai_pane" "$ai" C-m

    tmux select-pane -t "$ai_pane"
}

# AI + lazygit + shell
nic() {
    tml pi
}

nicx() {
    tml opencode
}
