# jw remove command

cmd_remove() {
    local name=""
    local force=false

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -f | --force)
            force=true
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

    # If no name provided, interactive selection or use current
    if [[ -z "$name" ]]; then
        if _is_interactive; then
            # Offer to select from non-default workspaces
            local workspaces
            workspaces=$(jj workspace list -T 'name ++ "\n"' 2>/dev/null | grep -v '^default$')

            if [[ -z "$workspaces" ]]; then
                _error "No removable workspaces found (only default exists)"
                return 1
            fi

            name=$(echo "$workspaces" | gum filter \
                --header "Select workspace to remove" \
                --placeholder "Type to filter...")

            [[ -z "$name" ]] && {
                _info "Cancelled"
                return 0
            }
        else
            name="$(_current_workspace)"
            if [[ "$name" == "default" ]]; then
                _error "Cannot remove the default workspace"
                _info "Usage: jw remove <workspace-name>"
                return 1
            fi
        fi
    fi

    if [[ "$name" == "default" ]]; then
        _error "Cannot remove the default workspace"
        return 1
    fi

    if ! _workspace_exists "$name"; then
        _error "Workspace '$name' does not exist"
        return 1
    fi

    local workspace_dir
    workspace_dir="$(_workspace_dir "$name")"

    # Check for uncommitted changes (unless --force)
    local has_changes=false
    if ! $force && [[ -d "$workspace_dir" ]]; then
        local diff_output
        if diff_output=$(jj diff --summary -r "@" --repository "$workspace_dir" 2>/dev/null); then
            if [[ -n "$diff_output" ]]; then
                has_changes=true
            fi
        fi
    fi

    # Confirm removal
    if ! $force; then
        _require_tty "Use -f to force removal without confirmation" || return 1

        _header "Remove Workspace"
        echo ""
        gum style --foreground 240 "Name: $name"
        gum style --foreground 240 "Path: $workspace_dir"

        if $has_changes; then
            echo ""
            gum style --foreground 214 --bold "⚠ Warning: Uncommitted changes will be lost!"
        fi

        echo ""
        gum confirm \
            --affirmative "Remove" \
            --negative "Cancel" \
            --default=false \
            "Remove workspace '$name'?" || {
            _info "Cancelled"
            return 0
        }
    fi

    # If we're in the workspace, cd to default first
    if [[ "$(pwd)" == "$workspace_dir" ]]; then
        local main_dir
        main_dir="$(_workspace_dir "default")"
        cd "$main_dir" || cd "$(_repo_root)" || return 1
        _info "Switched to default workspace"
    fi

    # Remove with spinner
    gum spin --spinner dot --title "Removing workspace..." -- \
        sh -c "jj workspace forget '$name' 2>/dev/null"

    # Clean up the directory
    if [[ -d "$workspace_dir" ]]; then
        rm -rf "$workspace_dir"
    fi

    _success "Removed workspace '$name'"
}

cmd_remove_help() {
    gum format <<'EOF'
# jw remove

Remove a workspace and its directory.

## Usage

```
jw remove [flags] [name]
```

## Flags

| Flag | Description |
|------|-------------|
| `-f, --force` | Skip confirmation and uncommitted changes check |

## Interactive Mode

When no name is provided:
- Shows filterable list of removable workspaces
- Cannot remove the default workspace

## Examples

```bash
# Remove specific workspace
jw remove my-feature

# Interactive selection
jw remove

# Force remove (skip confirmation)
jw remove -f old-branch
```

## Notes

- If you're in the workspace being removed, you'll be switched to default
- Uncommitted changes are warned about (use `-f` to skip)
- The workspace directory is deleted after removal
EOF
}
