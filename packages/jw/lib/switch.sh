# jw switch command

cmd_switch() {
    local create=false
    local execute=""
    local name=""

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -c | --create)
            create=true
            shift
            ;;
        -x | --execute)
            shift
            execute="$1"
            shift
            ;;
        -*)
            _error "Unknown flag: $1"
            return 1
            ;;
        *)
            name="$1"
            shift
            ;;
        esac
    done

    # Interactive mode when no name provided
    if [[ -z "$name" ]]; then
        if $create; then
            # Prompt for new workspace name
            _require_tty "Usage: jw switch -c <workspace-name>" || return 1
            name=$(gum input \
                --prompt "Workspace name: " \
                --placeholder "my-feature" \
                --char-limit 50)
            [[ -z "$name" ]] && {
                _error "Workspace name required"
                return 1
            }
        else
            # Select from existing workspaces
            _require_tty "Usage: jw switch <workspace-name>" || return 1
            local workspaces
            workspaces=$(_workspace_names)
            if [[ -z "$workspaces" ]]; then
                _error "No workspaces found"
                return 1
            fi
            name=$(echo "$workspaces" | gum filter \
                --header "Select workspace" \
                --placeholder "Type to filter..." \
                --indicator "▶")
            [[ -z "$name" ]] && {
                _info "Cancelled"
                return 0
            }
        fi
    fi

    # Check if workspace already exists
    if _workspace_exists "$name"; then
        local workspace_dir
        workspace_dir="$(_workspace_dir "$name")"

        # Check if we're already there
        if [[ "$(pwd)" == "$workspace_dir" ]]; then
            _info "Already in workspace '$name'"
        else
            cd "$workspace_dir" || return 1
            _success "Switched to workspace '$name'"
        fi
    elif $create; then
        # Create new workspace
        cmd_create "$name"
    else
        _error "Workspace '$name' does not exist"
        _info "Use 'jw switch -c $name' to create it"
        return 1
    fi

    # Prompt for editor if creating and no execute specified
    if [[ -z "$execute" ]] && $create && _is_interactive; then
        if gum confirm "Launch editor?"; then
            execute=$(gum choose \
                --header "Select editor" \
                "claude" "opencode" "code" "nvim" "zed" "none")
            [[ "$execute" == "none" ]] && execute=""
        fi
    fi

    # Execute command if specified
    if [[ -n "$execute" ]]; then
        _execute_command "$execute"
    fi
}

cmd_create() {
    local name="${1:-}"

    if [[ -z "$name" ]]; then
        _require_tty "Usage: jw create <workspace-name>" || return 1
        name=$(gum input \
            --prompt "Workspace name: " \
            --placeholder "my-feature" \
            --char-limit 50)
        [[ -z "$name" ]] && {
            _error "Workspace name required"
            return 1
        }
    fi

    if _workspace_exists "$name"; then
        _error "Workspace '$name' already exists"
        return 1
    fi

    local workspace_path
    workspace_path="$(_workspace_path "$name")"

    _header "Creating workspace: $name"

    # Create the workspace with spinner
    if ! gum spin --spinner dot --title "Creating workspace..." -- \
        jj workspace add --name "$name" "$workspace_path"; then
        _error "Failed to create workspace"
        return 1
    fi

    # Trust mise/direnv if present
    if [[ -f "$workspace_path/.mise.toml" ]]; then
        mise trust "$workspace_path" 2>/dev/null || true
    fi
    if [[ -f "$workspace_path/.envrc" ]]; then
        direnv allow "$workspace_path" 2>/dev/null || true
    fi

    _success "Created workspace at $workspace_path"

    # Switch to the workspace
    cd "$workspace_path" || return 1
}

cmd_switch_help() {
    gum format <<'EOF'
# jw switch

Switch to an existing workspace or create a new one.

## Usage

```
jw switch [flags] [name]
```

## Flags

| Flag | Description |
|------|-------------|
| `-c, --create` | Create workspace if it doesn't exist |
| `-x, --execute <cmd>` | Execute command after switching |

## Interactive Mode

When no name is provided:
- **Switch mode**: Shows filterable list of workspaces
- **Create mode** (`-c`): Prompts for workspace name

## Examples

```bash
# Switch to existing workspace
jw switch my-feature

# Interactive selection
jw switch

# Create and switch
jw switch -c new-feature

# Create with editor
jw switch -c -x claude agent-1
```

## Execute Options

Built-in commands: `claude`, `opencode`, `code`, `nvim`, `zed`

Any other value is executed as a shell command.
EOF
}
