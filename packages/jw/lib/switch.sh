# jw switch command

cmd_switch() {
    local create=false
    local execute=""
    local name=""
    
    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--create)
                create=true
                shift
                ;;
            -x|--execute)
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
    
    if [[ -z "$name" ]]; then
        echo "Usage: jw switch [-c] [-x <command>] <workspace-name>"
        echo ""
        echo "Flags:"
        echo "  -c, --create     Create new workspace if it doesn't exist"
        echo "  -x, --execute    Execute command after switching (claude, code, nvim)"
        echo ""
        echo "Examples:"
        echo "  jw switch feat           # Switch to existing workspace"
        echo "  jw switch -c feat        # Create and switch to workspace"  
        echo "  jw switch -c -x claude   # Create, switch, and start Claude"
        return 1
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
        echo "Use 'jw switch -c $name' to create it"
        return 1
    fi
    
    # Execute command if specified
    if [[ -n "$execute" ]]; then
        _execute_command "$execute"
    fi
}

cmd_create() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        echo "Usage: jw create <workspace-name>"
        return 1
    fi
    
    if _workspace_exists "$name"; then
        _error "Workspace '$name' already exists"
        return 1
    fi
    
    local workspace_path
    workspace_path="$(_workspace_path "$name")"
    
    echo "Creating workspace '$name'..."
    
    # Create the workspace
    if ! jj workspace add --name "$name" "$workspace_path"; then
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
    
    _success "Created workspace '$name' at $workspace_path"
    
    # Switch to the workspace
    cd "$workspace_path" || return 1
    
    _info "Switched to workspace"
}
