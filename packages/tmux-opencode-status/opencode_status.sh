#!/usr/bin/env bash
# Enhanced OpenCode state monitor for tmux window names
# States: idle (○), busy (●), waiting (◉), error (✗), finished (✔)
#
# Upstream: https://github.com/IFAKA/tmux-opencode-status
#
# Enhancements over upstream:
# - Added FINISHED state (✔) when agent completes and returns control
# - Fixed false error detection (was matching UI characters and nix build output)
# - Smarter error detection only triggers on actual agent crashes
# - Added detection for "Allow once/Allow always/Reject" permission prompts
# - 2-second confirmation delay for finished state to avoid false positives

# Configuration: delay before confirming finished state (seconds)
FINISHED_DELAY="${OPENCODE_STATUS_FINISHED_DELAY:-2}"

# Icons (plain - tmux color codes don't work in window names)
ICON_IDLE="○"
ICON_BUSY="●"
ICON_WAITING="◉"
ICON_ERROR="✗"
ICON_FINISHED="✔"

# Detect state from pane content
# Priority: error > waiting > busy > finished > idle
detect_state() {
    local pane_id="$1"
    local lines
    lines=$(tmux capture-pane -p -t "$pane_id" -S -15 2>/dev/null)

    [ -z "$lines" ] && echo "idle" && return

    # Check for OpenCode UI elements (indicates session is active)
    local has_opencode_ui
    has_opencode_ui=$(echo "$lines" | grep -cE "(⬝|esc interrupt|tab switch agent|ctrl\+p commands)")

    # ERROR: Only detect errors when OpenCode UI is NOT visible
    # This means the agent actually crashed, not just displaying error output
    if [ "$has_opencode_ui" -eq 0 ]; then
        # Check for Python/JS runtime errors that indicate agent failure
        if echo "$lines" | grep -qE "(Traceback \(most recent|UnhandledPromiseRejection|FATAL ERROR:)"; then
            echo "error"
            return
        fi
    fi

    # WAITING: Permission prompts (OpenCode specific patterns)
    # Includes both classic [Y/n] style and OpenCode's "Allow once/Allow always/Reject" dialog
    if echo "$lines" | grep -qiE "(\[Y/n\]|\[y/N\]|y/n|Allow once|Allow always|Reject|permission|approve|confirm)"; then
        echo "waiting"
        return
    fi

    # BUSY: Active processing indicators
    # - Braille spinners (⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏)
    # - Circle spinners (●◐◓◑◒)
    # - "thinking", "Thinking", "Tool:"
    if echo "$lines" | grep -qE "(⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏|◐|◓|◑|◒|thinking|Thinking|Tool:)"; then
        echo "busy"
        return
    fi

    # Check for animated progress bar (has both empty and filled segments)
    if echo "$lines" | grep -qE "⬝.*■|■.*⬝"; then
        echo "busy"
        return
    fi

    # FINISHED: Agent completed, prompt ready
    # Conditions:
    # - Empty progress bar present (⬝⬝⬝⬝⬝⬝⬝⬝) - no filled segments
    # - "esc interrupt" visible (session is active)
    # - Status bar visible ("tab switch agent" or "ctrl+p commands")
    # - No busy indicators
    local has_empty_progress
    local has_esc_interrupt
    local has_status_bar
    has_empty_progress=$(echo "$lines" | grep -cE "⬝⬝⬝⬝⬝⬝⬝⬝")
    has_esc_interrupt=$(echo "$lines" | grep -cE "esc interrupt")
    has_status_bar=$(echo "$lines" | grep -cE "(tab switch agent|ctrl\+p commands|OpenCode)")

    if [ "$has_empty_progress" -gt 0 ] && [ "$has_esc_interrupt" -gt 0 ] && [ "$has_status_bar" -gt 0 ]; then
        # Wait to confirm state is stable (not mid-animation)
        sleep "$FINISHED_DELAY"

        # Re-capture and verify state hasn't changed to busy
        local recheck
        recheck=$(tmux capture-pane -p -t "$pane_id" -S -15 2>/dev/null)

        # Check if still has empty progress bar (no animation)
        if echo "$recheck" | grep -qE "⬝⬝⬝⬝⬝⬝⬝⬝"; then
            # Verify no busy indicators appeared
            if ! echo "$recheck" | grep -qE "(⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏|◐|◓|◑|◒|thinking|Thinking|Tool:|⬝.*■|■.*⬝)"; then
                echo "finished"
                return
            fi
        fi

        # State changed during wait - it's busy
        echo "busy"
        return
    fi

    # IDLE: Default state (OpenCode open but no active session detected)
    echo "idle"
}

get_icon() {
    case "$1" in
    idle) echo "$ICON_IDLE" ;;
    busy) echo "$ICON_BUSY" ;;
    waiting) echo "$ICON_WAITING" ;;
    error) echo "$ICON_ERROR" ;;
    finished) echo "$ICON_FINISHED" ;;
    *) echo "$ICON_IDLE" ;;
    esac
}

# Strip all existing icons from window name
strip_icons() {
    echo "$1" | sed -E 's/ [○●◉✗✔]+$//'
}

# Check if pane runs opencode
is_opencode() {
    local cmd="$1"
    local pid="$2"

    if echo "$cmd" | grep -qiE "^(oc|opencode)$"; then
        return 0
    elif [ "$cmd" = "node" ]; then
        ps -p "$pid" -o command= 2>/dev/null | grep -qiE "(opencode|oc)" && return 0
    fi
    return 1
}

# Main: update window names with icons for each opencode pane
main() {
    tmux list-windows -F "#{window_index} #{window_name}" | while read -r idx name; do
        local icons=""

        # Check ALL panes in this window
        while IFS= read -r pane_line; do
            local pane_id pane_cmd pane_pid
            pane_id=$(echo "$pane_line" | awk '{print $1}')
            pane_cmd=$(echo "$pane_line" | awk '{print $2}')
            pane_pid=$(echo "$pane_line" | awk '{print $3}')

            if is_opencode "$pane_cmd" "$pane_pid"; then
                local state icon
                state=$(detect_state "$pane_id")
                icon=$(get_icon "$state")
                icons="${icons}${icon}"
            fi
        done < <(tmux list-panes -t ":$idx" -F "#{pane_id} #{pane_current_command} #{pane_pid}")

        local base_name
        base_name=$(strip_icons "$name")

        if [ -n "$icons" ]; then
            local new_name="$base_name $icons"
            [ "$name" != "$new_name" ] && tmux rename-window -t ":$idx" "$new_name"
        else
            # No opencode in this window - restore base name if needed
            [ "$name" != "$base_name" ] && tmux rename-window -t ":$idx" "$base_name"
        fi
    done
}

# Only run main if not being sourced (for testing)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
