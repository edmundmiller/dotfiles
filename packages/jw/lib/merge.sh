# jw merge command

cmd_merge() {
    local name=""
    local squash=false
    
    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --squash|-s)
                squash=true
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
    
    # If no name, use current workspace
    if [[ -z "$name" ]]; then
        name="$(_current_workspace)"
    fi
    
    if [[ "$name" == "default" ]]; then
        _error "Cannot merge the default workspace"
        return 1
    fi
    
    if ! _workspace_exists "$name"; then
        _error "Workspace '$name' does not exist"
        return 1
    fi
    
    local workspace_dir
    workspace_dir="$(_workspace_dir "$name")"
    
    echo "Merging workspace '$name' to trunk..."
    
    # Get commits ahead of trunk in the workspace
    local commits
    commits=$(jj log -r "${name}@ ~ trunk()" --no-graph -T 'change_id.short() ++ "\n"' --repository "$workspace_dir" 2>/dev/null)
    
    if [[ -z "$commits" ]]; then
        _warn "Workspace '$name' has no commits ahead of trunk"
        return 0
    fi
    
    local commit_count
    commit_count=$(echo "$commits" | grep -c .)
    
    echo "Found $commit_count commit(s) to merge"
    
    # Rebase workspace commits onto trunk
    if $squash; then
        echo "Squashing commits..."
        # Squash all commits into one on trunk
        jj squash --from "${name}@-" --into "trunk()" --repository "$workspace_dir"
    else
        echo "Rebasing onto trunk..."
        # Rebase the workspace commits onto trunk
        jj rebase -s "roots(${name}@ ~ trunk())" -d "trunk()" --repository "$workspace_dir"
    fi
    
    _success "Merged '$name' into trunk"
    echo ""
    echo "Next steps:"
    echo "  jj git push        # Push to remote"
    echo "  jw remove $name    # Clean up workspace"
}
