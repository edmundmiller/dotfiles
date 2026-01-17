# jw remove command

cmd_remove() {
    local name=""
    local force=false
    
    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force)
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
    
    # If no name provided, use current workspace
    if [[ -z "$name" ]]; then
        name="$(_current_workspace)"
        if [[ "$name" == "default" ]]; then
            _error "Cannot remove the default workspace"
            echo "Specify a workspace name: jw remove <name>"
            return 1
        fi
    fi
    
    if ! _workspace_exists "$name"; then
        _error "Workspace '$name' does not exist"
        return 1
    fi
    
    local workspace_dir
    workspace_dir="$(_workspace_dir "$name")"
    
    # Check for uncommitted changes (unless --force)
    if ! $force && [[ -d "$workspace_dir" ]]; then
        local diff_output
        if diff_output=$(jj diff --summary -r "@" 2>/dev/null --repository "$workspace_dir"); then
            if [[ -n "$diff_output" ]]; then
                _error "Workspace '$name' has uncommitted changes"
                echo "Use 'jw remove -f $name' to force removal"
                return 1
            fi
        fi
    fi
    
    # Confirm removal (skip if force or no TTY)
    if ! $force; then
        if [[ -t 0 ]]; then
            if command -v gum &>/dev/null; then
                gum confirm "Remove workspace '$name'?" || return 0
            else
                echo -n "Remove workspace '$name'? [y/N] "
                read -r confirm
                [[ "$confirm" =~ ^[Yy]$ ]] || return 0
            fi
        else
            _error "No TTY available for confirmation. Use -f to force removal."
            return 1
        fi
    fi
    
    # If we're in the workspace, cd to parent first
    if [[ "$(pwd)" == "$workspace_dir" ]]; then
        local main_dir
        main_dir="$(_workspace_dir "default")"
        cd "$main_dir" || cd "$(_repo_root)" || return 1
    fi
    
    # Remove the workspace
    jj workspace forget "$name"
    
    # Clean up the directory
    if [[ -d "$workspace_dir" ]]; then
        rm -rf "$workspace_dir"
        _success "Removed workspace directory: $workspace_dir"
    fi
    
    _success "Workspace '$name' removed"
}
