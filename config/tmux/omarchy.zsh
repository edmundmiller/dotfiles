#!/usr/bin/env zsh
# Omarchy-inspired tmux dev layouts
# https://github.com/basecamp/omarchy/blob/dev/default/bash/fns/tmux

# tml — tmux dev layout: AI tool (70%) + lazygit (30%) right, shell (15%) bottom
tml() {
  [[ -z $TMUX ]] && { echo "You must start tmux to use tml."; return 1; }

  local current_dir="${PWD}"
  local ai_pane
  local ai="$1"

  # Use TMUX_PANE for stability even if active window changes
  ai_pane="$TMUX_PANE"

  # Name window after current dir
  tmux rename-window -t "$ai_pane" "$(basename "$current_dir")"

  # Bottom shell pane (15%)
  tmux split-window -v -p 15 -t "$ai_pane" -c "$current_dir"

  # Back to top, split for lazygit (30% right)
  local lg_main="$HOME/.config/lazygit/config.yml"
  local lg_tml="$HOME/.config/lazygit/tml.yml"
  tmux split-window -h -p 30 -t "$ai_pane" -c "$current_dir" \
    "lazygit --use-config-file='${lg_main},${lg_tml}'"

  # Launch AI in left pane
  tmux send-keys -t "$ai_pane" "$ai" C-m

  tmux select-pane -t "$ai_pane"
}

# tmlm — tml window per subdirectory in current directory
tmlm() {
  [[ -z $TMUX ]] && { echo "You must start tmux to use tmlm."; return 1; }

  local ai="$1"
  local base_dir="$PWD"
  local first=true

  tmux rename-session "$(basename "$base_dir" | tr '.:' '--')"

  for dir in "$base_dir"/*/; do
    [[ -d $dir ]] || continue
    local dirpath="${dir%/}"

    if $first; then
      tmux send-keys -t "$TMUX_PANE" "cd '$dirpath' && tml $ai" C-m
      first=false
    else
      local pane_id
      pane_id=$(tmux new-window -c "$dirpath" -P -F '#{pane_id}')
      tmux send-keys -t "$pane_id" "tml $ai" C-m
    fi
  done
}

# Shortcuts: pi + lazygit + shell
nic()  { tml pi; }

# opencode + lazygit + shell
nicx() { tml opencode; }

# tml for each subdir using pi
nicm()  { tmlm pi; }

# tml for each subdir using opencode
nicxm() { tmlm opencode; }
