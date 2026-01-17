# jw list command

cmd_list() {
    local full=false
    local format="table"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --full|-f)
                full=true
                shift
                ;;
            --json)
                format="json"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    local current_ws
    current_ws="$(_current_workspace)"
    local repo_root
    repo_root="$(_repo_root)"
    
    if [[ "$format" == "json" ]]; then
        _list_json "$full"
        return
    fi
    
    # Header
    printf "${BOLD}%-15s %-12s %-8s %s${NC}\n" "WORKSPACE" "STATUS" "AHEAD" "PATH"
    
    local count=0
    local dirty_count=0
    local ahead_count=0
    
    # Get workspace names from jj workspace list using template
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        
        # Compute path based on workspace name
        local path
        if [[ "$name" == "default" ]]; then
            path="$repo_root"
        else
            path="$(_workspace_path "$name")"
        fi
        
        count=$((count + 1))
        
        # Get status
        local status=""
        local status_symbol=""
        local ahead=""
        
        if [[ -d "$path" ]]; then
            # Check for uncommitted changes
            local diff_output
            if diff_output=$(jj diff --summary -r "@" 2>/dev/null --at-op=@ --ignore-working-copy --repository "$path"); then
                if [[ -n "$diff_output" ]]; then
                    status="dirty"
                    status_symbol="${YELLOW}${DOT}${NC}"
                    dirty_count=$((dirty_count + 1))
                else
                    status="clean"
                    status_symbol="${GREEN}${DOT}${NC}"
                fi
            else
                status="?"
                status_symbol="${DIM}?${NC}"
            fi
            
            # Count commits ahead of trunk
            if $full; then
                local ahead_num
                ahead_num=$(jj log -r "@ ~ trunk()" --no-graph -T 'commit_id ++ "\n"' 2>/dev/null --repository "$path" | grep -c . || echo "0")
                if [[ "$ahead_num" -gt 0 ]]; then
                    ahead="↑$ahead_num"
                    ahead_count=$((ahead_count + 1))
                fi
            fi
        else
            status="missing"
            status_symbol="${RED}${CROSS}${NC}"
        fi
        
        # Current indicator
        local prefix=" "
        if [[ "$name" == "$current_ws" ]]; then
            prefix="${CYAN}*${NC}"
        fi
        
        # Format path for display (relative if possible)
        local display_path="$path"
        if [[ "$path" == "$HOME"* ]]; then
            display_path="~${path#$HOME}"
        fi
        
        printf "${prefix}%-14s ${status_symbol} %-10s %-8s ${DIM}%s${NC}\n" "$name" "$status" "$ahead" "$display_path"
        
    done < <(jj workspace list -T 'name ++ "\n"' 2>/dev/null)
    
    # Summary
    echo ""
    local summary="$count workspace"
    [[ $count -ne 1 ]] && summary+="s"
    
    if [[ $dirty_count -gt 0 ]]; then
        summary+=", $dirty_count with changes"
    fi
    if [[ $ahead_count -gt 0 ]]; then
        summary+=", $ahead_count ahead"
    fi
    
    _info "Showing $summary"
}

_list_json() {
    local full="$1"
    local current_ws
    current_ws="$(_current_workspace)"
    local repo_root
    repo_root="$(_repo_root)"
    
    echo "{"
    echo '  "workspaces": ['
    
    local first=true
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        
        # Compute path based on workspace name
        local path
        if [[ "$name" == "default" ]]; then
            path="$repo_root"
        else
            path="$(_workspace_path "$name")"
        fi
        
        $first || echo ","
        first=false
        
        local is_current=false
        [[ "$name" == "$current_ws" ]] && is_current=true
        
        local has_changes=false
        local ahead=0
        
        if [[ -d "$path" ]]; then
            local diff_output
            if diff_output=$(jj diff --summary -r "@" 2>/dev/null --repository "$path"); then
                [[ -n "$diff_output" ]] && has_changes=true
            fi
            
            if $full; then
                ahead=$(jj log -r "@ ~ trunk()" --no-graph -T 'commit_id ++ "\n"' 2>/dev/null --repository "$path" | grep -c . || echo "0")
            fi
        fi
        
        printf '    {"name": "%s", "path": "%s", "current": %s, "has_changes": %s, "ahead": %d}' \
            "$name" "$path" "$is_current" "$has_changes" "$ahead"
    done < <(jj workspace list -T 'name ++ "\n"' 2>/dev/null)
    
    echo ""
    echo "  ]"
    echo "}"
}
