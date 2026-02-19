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
    local lg_tml="$HOME/.config/sesh/lazygit-tml.yml"
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
