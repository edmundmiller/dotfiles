# jw select command - interactive workspace picker

cmd_select() {
    _require_tty "select requires an interactive terminal" || return 1

    local workspaces
    workspaces=$(_workspace_names)

    if [[ -z "$workspaces" ]]; then
        _error "No workspaces found"
        return 1
    fi

    local current_ws
    current_ws="$(_current_workspace)"

    # Build list with status indicators
    local display_list=""
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue

        local path
        if [[ "$name" == "default" ]]; then
            path="$(_repo_root)"
        else
            path="$(_workspace_path "$name")"
        fi

        local prefix=""
        if [[ "$name" == "$current_ws" ]]; then
            prefix="● "
        else
            prefix="  "
        fi

        # Check for uncommitted changes
        local status=""
        if [[ -d "$path" ]]; then
            local diff_output
            if diff_output=$(jj diff --summary -r "@" --at-op=@ --ignore-working-copy --repository "$path" 2>/dev/null); then
                if [[ -n "$diff_output" ]]; then
                    status=" [modified]"
                fi
            fi
        else
            status=" [missing]"
        fi

        display_list+="${prefix}${name}${status}"$'\n'
    done <<<"$workspaces"

    # Show filter with status
    local selected
    selected=$(echo -n "$display_list" | gum filter \
        --header "Select workspace (● = current)" \
        --placeholder "Type to filter..." \
        --indicator "▶" \
        --height 15)

    [[ -z "$selected" ]] && {
        _info "Cancelled"
        return 0
    }

    # Extract workspace name (remove prefix and status)
    local name
    name=$(echo "$selected" | sed 's/^[● ] //' | sed 's/ \[.*\]$//')

    # Switch to selected workspace
    local workspace_dir
    workspace_dir="$(_workspace_dir "$name")"

    if [[ ! -d "$workspace_dir" ]]; then
        _error "Workspace directory not found: $workspace_dir"
        return 1
    fi

    cd "$workspace_dir" || return 1
    _success "Switched to workspace '$name'"
}

cmd_select_help() {
    gum format <<'EOF'
# jw select

Interactive workspace picker with fuzzy filtering.

## Usage

```
jw select
```

## Features

- Fuzzy search through all workspaces
- Status indicators show current and modified workspaces
- Press Enter to switch, Escape to cancel

## Indicators

| Symbol | Meaning |
|--------|---------|
| `●` | Current workspace |
| `[modified]` | Has uncommitted changes |
| `[missing]` | Directory not found |

## Keyboard

| Key | Action |
|-----|--------|
| `↑/↓` | Navigate |
| `Enter` | Select and switch |
| `Esc` | Cancel |
| Type | Filter workspaces |
EOF
}
