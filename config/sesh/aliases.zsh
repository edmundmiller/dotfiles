# sesh — tmux split: AI tool (70%) + lazygit (30%) side by side
# Inspired by almonk/sesh and basecamp/omarchy tml()
sesh() {
    if ! command -v lazygit &>/dev/null; then
        echo "sesh: 'lazygit' is not installed"
        return 1
    fi

    local tool="${1:-claude}"
    tool="$(echo "$tool" | tr '[:upper:]' '[:lower:]')"

    case "$tool" in
        help|--help|-h)
            echo "Usage: sesh [tool] [directory]"
            echo ""
            echo "Tools: claude (default), codex, opencode, amp, pi, or any binary"
            echo ""
            echo "  sesh                     # claude + lazygit in cwd"
            echo "  sesh pi ~/project        # pi + lazygit in ~/project"
            echo ""
            echo "Keybinds: use normal tmux pane navigation"
            return 0
            ;;
    esac

    local dir="${2:-$(pwd)}"
    dir="$(realpath "$dir" 2>/dev/null)" || {
        echo "sesh: invalid directory: $2"
        return 1
    }

    if ! command -v "$tool" &>/dev/null; then
        echo "sesh: '$tool' is not installed or not in PATH"
        return 1
    fi

    # If not in tmux, start a new session
    if [[ -z "$TMUX" ]]; then
        tmux new-session -d -s sesh -c "$dir"
        tmux send-keys -t sesh "$tool" C-m
        tmux split-window -h -p 30 -c "$dir" "lazygit"
        tmux select-pane -t 0
        tmux attach-session -t sesh
        return
    fi

    # Already in tmux — split current pane
    local tool_pane
    tool_pane=$(tmux display-message -p '#{pane_id}')

    tmux split-window -h -p 30 -c "$dir" "lazygit"
    tmux select-pane -t "$tool_pane"
    tmux send-keys -t "$tool_pane" "$tool" C-m
}
