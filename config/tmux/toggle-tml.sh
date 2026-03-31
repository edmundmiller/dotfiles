#!/usr/bin/env bash
# Toggle tml layout: AI pane + lazygit + shell
# 1 pane → create layout, >1 pane → kill extras (keep current)

set -euo pipefail

bin_script() {
  local script_name="$1"
  local script_path="${DOTFILES_BIN:-$HOME/.config/dotfiles/bin}/$script_name"
  [[ -x "$script_path" ]] || script_path="$HOME/.config/dotfiles/bin/$script_name"
  [[ -x "$script_path" ]] || return 1
  printf '%s\n' "$script_path"
}

pane_count=$(tmux list-panes | wc -l | tr -d ' ')
current_dir="$(tmux display-message -p '#{pane_current_path}')"

if resolver=$(bin_script git-worktree-cwd); then
  current_dir=$($resolver "$current_dir")
fi

if project_name_helper=$(bin_script tmux-project-name); then
  project_name=$($project_name_helper "$current_dir")
else
  project_name=$(basename -- "$current_dir" | sed -E 's/[^[:alnum:]_-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')
fi

if [ "$pane_count" -eq 1 ]; then
    ai_pane=$(tmux display-message -p '#{pane_id}')

    tmux rename-window -t "$ai_pane" "$project_name"

    # Bottom shell (15%)
    tmux split-window -v -p 15 -c "$current_dir"

    # Back to top, lazygit right (30%)
    tmux select-pane -t "$ai_pane"
    lg_main="$HOME/.config/lazygit/config.yml"
    lg_tml="$HOME/.config/lazygit/tml.yml"
    tmux split-window -h -p 30 -c "$current_dir" \
        "lazygit --use-config-file='${lg_main},${lg_tml}'"

    tmux select-pane -t "$ai_pane"
else
    # Kill all panes except current
    current_pane=$(tmux display-message -p '#{pane_id}')
    tmux list-panes -F '#{pane_id}' | while read -r pane; do
        [ "$pane" != "$current_pane" ] && tmux kill-pane -t "$pane"
    done
fi
