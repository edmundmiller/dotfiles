# tml — tmux dev layout: AI + lazygit on top, shell at bottom
tml() {
    local current_dir="${PWD}"
    local ai_pane
    local ai="$1"

    ai_pane=$(tmux display-message -p '#{pane_id}')

    # Bottom shell pane (15%)
    tmux split-window -v -p 15 -c "$current_dir"

    # Back to top, split for lazygit (30% right)
    tmux select-pane -t "$ai_pane"
    tmux split-window -h -p 30 -c "$current_dir" "lazygit"

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
