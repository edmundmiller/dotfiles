# jw sync command

cmd_sync() {
    local name="${1:-}"
    
    if [[ -z "$name" ]]; then
        name="$(_current_workspace)"
    fi
    
    if [[ "$name" == "default" ]]; then
        _error "Cannot sync the default workspace (already at trunk)"
        return 1
    fi
    
    if ! _workspace_exists "$name"; then
        _error "Workspace '$name' does not exist"
        return 1
    fi
    
    local workspace_dir
    workspace_dir="$(_workspace_dir "$name")"
    
    echo "Syncing workspace '$name' with trunk..."
    
    # Rebase workspace onto latest trunk
    jj rebase -s "roots(${name}@ ~ trunk())" -d "trunk()" --repository "$workspace_dir"
    
    _success "Synced '$name' with trunk"
}
