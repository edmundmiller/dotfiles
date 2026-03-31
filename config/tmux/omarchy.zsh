#!/usr/bin/env zsh
# Omarchy-inspired tmux dev layouts
# https://github.com/basecamp/omarchy/blob/dev/default/bash/fns/tmux

_dotfiles_bin_script() {
  local script_name="$1"
  local script_path="${DOTFILES_BIN:-$HOME/.config/dotfiles/bin}/$script_name"
  [[ -x "$script_path" ]] || script_path="$HOME/.config/dotfiles/bin/$script_name"
  [[ -x "$script_path" ]] || return 1
  printf '%s\n' "$script_path"
}

_git_worktree_cwd() {
  local resolver
  if ! resolver=$(_dotfiles_bin_script git-worktree-cwd); then
    echo "$1"
    return 0
  fi
  "$resolver" "$1"
}

_tmux_project_name() {
  local resolver
  if ! resolver=$(_dotfiles_bin_script tmux-project-name); then
    basename -- "$1" | sed -E 's/[^[:alnum:]_-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
    return 0
  fi
  "$resolver" "$1"
}

# tml — tmux dev layout: AI tool (70%) + lazygit (30%) right, shell (15%) bottom
tml() {
  [[ -z $TMUX ]] && { echo "You must start tmux to use tml."; return 1; }

  local current_dir
  current_dir=$(_git_worktree_cwd "$PWD") || return 1
  local ai_pane
  local ai="$1"

  # Use TMUX_PANE for stability even if active window changes
  ai_pane="$TMUX_PANE"

  # Name window after current dir
  tmux rename-window -t "$ai_pane" "$(_tmux_project_name "$current_dir")"

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

  tmux rename-session "$(_tmux_project_name "$base_dir")"

  for dir in "$base_dir"/*/; do
    [[ -d $dir ]] || continue
    local dirpath
    dirpath=$(_git_worktree_cwd "${dir%/}") || continue

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

# tmlc — like tml but with critique instead of lazygit
# Right column (30%): unstaged on top, staged on bottom
tmlc() {
  [[ -z $TMUX ]] && { echo "You must start tmux to use tmlc."; return 1; }

  local current_dir
  current_dir=$(_git_worktree_cwd "$PWD") || return 1
  local ai_pane critique_pane
  local ai="$1"

  ai_pane="$TMUX_PANE"

  tmux rename-window -t "$ai_pane" "$(_tmux_project_name "$current_dir")"

  # Bottom shell pane (15%)
  tmux split-window -v -p 15 -t "$ai_pane" -c "$current_dir"

  # Back to top, split right column (30%) for unstaged critique
  critique_pane=$(tmux split-window -h -p 30 -t "$ai_pane" -c "$current_dir" -P -F '#{pane_id}' \
    "$HOME/.config/tmux/open-critique.sh")

  # Split critique pane: bottom half for staged
  tmux split-window -v -p 50 -t "$critique_pane" -c "$current_dir" \
    "$HOME/.config/tmux/open-critique.sh --staged"

  # Launch AI in left pane
  tmux send-keys -t "$ai_pane" "$ai" C-m

  tmux select-pane -t "$ai_pane"
}

# AI + critique + shell
nicc()  { tmlc pi; }
niccx() { tmlc opencode; }
