#!/usr/bin/env bash
# Toggle tml layout: AI pane + lazygit + shell
# 1 pane → create layout, >1 pane → kill extras (keep current)

pane_count=$(tmux list-panes | wc -l | tr -d ' ')
current_dir="$(tmux display-message -p '#{pane_current_path}')"

if [ "$pane_count" -eq 1 ]; then
    ai_pane=$(tmux display-message -p '#{pane_id}')

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
