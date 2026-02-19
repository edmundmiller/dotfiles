# tml — tmux dev layout: editor (70%) + AI (30%) on top, terminal (15%) on bottom
# Inspired by basecamp/omarchy
tml() {
    local current_dir="${PWD}"
    local editor_pane ai_pane
    local ai="$1"

    editor_pane=$(tmux display-message -p '#{pane_id}')

    # Bottom terminal pane (15%)
    tmux split-window -v -p 15 -c "$current_dir"

    # Back to top, split horizontally for AI (30% right)
    tmux select-pane -t "$editor_pane"
    tmux split-window -h -p 30 -c "$current_dir"

    ai_pane=$(tmux display-message -p '#{pane_id}')
    tmux send-keys -t "$ai_pane" "$ai" C-m

    # Editor in left pane
    tmux send-keys -t "$editor_pane" "$EDITOR ." C-m

    tmux select-pane -t "$editor_pane"
}

# editor + pi + terminal
nic() {
    tml pi
}

# editor + opencode + terminal
nicx() {
    tml opencode
}
