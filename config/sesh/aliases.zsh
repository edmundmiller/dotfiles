# almonk/sesh — zellij split: AI tool (65%) + lazygit (35%)
# https://github.com/almonk/sesh
sesh() {
    for dep in zellij lazygit; do
        if ! command -v "$dep" &>/dev/null; then
            echo "sesh: '$dep' is not installed"
            return 1
        fi
    done

    local tool="${1:-claude}"
    tool="$(echo "$tool" | tr '[:upper:]' '[:lower:]')"

    if [[ "$tool" == "list" ]]; then
        zellij list-sessions
        return
    fi

    if [[ "$tool" == "pickup" ]]; then
        local session
        session="$(zellij list-sessions 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | head -1 | awk '{print $1}')"
        if [[ -z "$session" ]]; then
            echo "sesh: no sessions found"
            return 1
        fi
        echo "sesh: attaching to $session"
        zellij attach "$session"
        return
    fi

    local dir="${2:-$(pwd)}"

    dir="$(realpath "$dir" 2>/dev/null)" || {
        echo "sesh: invalid directory: $2"
        return 1
    }

    local cmd_block

    case "$tool" in
        claude)
            cmd_block="pane size=\"65%\" command=\"claude\" {
            args \"--dangerously-skip-permissions\"
            cwd \"$dir\"
        }"
            ;;
        codex)
            cmd_block="pane size=\"65%\" command=\"codex\" {
            cwd \"$dir\"
        }"
            ;;
        opencode)
            cmd_block="pane size=\"65%\" command=\"opencode\" {
            cwd \"$dir\"
        }"
            ;;
        amp)
            cmd_block="pane size=\"65%\" command=\"amp\" {
            cwd \"$dir\"
        }"
            ;;
        pi)
            cmd_block="pane size=\"65%\" command=\"pi\" {
            cwd \"$dir\"
        }"
            ;;
        help|--help|-h)
            echo "Usage: sesh [tool] [directory]"
            echo ""
            echo "Tools: claude (default), codex, opencode, amp, pi, or any binary"
            echo "Subcommands: list, pickup, help"
            echo ""
            echo "  sesh                     # claude + lazygit in cwd"
            echo "  sesh pi ~/project        # pi + lazygit in ~/project"
            echo "  sesh pickup              # reattach last session"
            echo ""
            echo "Keybinds: Alt-1/2 switch panes, Ctrl-q detach"
            return 0
            ;;
        *)
            if ! command -v "$tool" &>/dev/null; then
                echo "sesh: '$tool' is not installed or not in PATH"
                return 1
            fi
            cmd_block="pane size=\"65%\" command=\"$tool\" {
            cwd \"$dir\"
        }"
            ;;
    esac

    local layout_dir layout_file
    layout_dir="$(mktemp -d /tmp/sesh-XXXXXX)"
    layout_file="$layout_dir/layout.kdl"
    cat > "$layout_file" <<EOF
keybinds {
    shared {
        bind "Alt 1" { MoveFocus "left"; }
        bind "Alt 2" { MoveFocus "right"; }
        bind "Ctrl q" { Detach; }
    }
}
layout {
    pane split_direction="vertical" {
        $cmd_block
        pane size="35%" command="lazygit" {
            cwd "$dir"
        }
    }
}
EOF

    zellij --layout "$layout_file"
    rm -rf "$layout_dir"
}
