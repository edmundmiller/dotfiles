# jw sync command

cmd_sync() {
    local name="${1:-}"

    # Use current workspace if no name provided
    if [[ -z "$name" ]]; then
        name="$(_current_workspace)"
    fi

    if ! _workspace_exists "$name"; then
        _error "Workspace '$name' does not exist"
        return 1
    fi

    local workspace_dir
    workspace_dir="$(_workspace_dir "$name")"

    _header "Sync Workspace: $name"

    # First, fetch from remote
    gum spin --spinner dot --title "Fetching from remote..." -- \
        jj git fetch --repository "$workspace_dir" 2>/dev/null || true

    # Check if there's anything to sync
    local commits
    commits=$(jj log -r "${name}@ ~ trunk()" --no-graph -T 'change_id.short() ++ "\n"' --repository "$workspace_dir" 2>/dev/null)

    if [[ -z "$commits" ]]; then
        _info "Workspace '$name' is already up to date with trunk"
        return 0
    fi

    local commit_count
    commit_count=$(echo "$commits" | grep -c .)

    gum style --foreground 240 "Rebasing $commit_count commit(s) onto trunk..."
    echo ""

    # Rebase onto trunk
    if gum spin --spinner dot --title "Syncing with trunk..." -- \
        jj rebase -s "roots(${name}@ ~ trunk())" -d "trunk()" --repository "$workspace_dir"; then
        _success "Synced '$name' with trunk"
    else
        _error "Sync failed - there may be conflicts"
        _info "Check with: jj status --repository '$workspace_dir'"
        return 1
    fi
}

cmd_sync_help() {
    gum format <<'EOF'
# jw sync

Sync workspace with trunk by rebasing.

## Usage

```
jw sync [name]
```

## Description

Fetches latest changes from remote and rebases workspace commits onto trunk.
This keeps your workspace up to date with the main branch.

## Examples

```bash
# Sync current workspace
jw sync

# Sync specific workspace
jw sync my-feature
```

## Conflict Handling

If conflicts occur during rebase:
1. jj will report the conflict
2. Resolve conflicts manually
3. Run `jj squash` to mark resolved

Use `jj status` to see current conflict state.
EOF
}
