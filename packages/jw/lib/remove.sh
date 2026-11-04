# jw remove command

_canonical_directory() {
    (cd -P -- "$1" 2>/dev/null && pwd -P)
}

# Resolve a workspace through jj's registry, then prove that the directory still
# identifies that workspace in the same repository as the caller.
_verified_workspace_root() {
    local name="$1"
    local source_root source_repo registered_root target_root target_repo

    source_root=$(jj workspace root 2>/dev/null) || return 1
    source_root=$(_canonical_directory "$source_root") || return 1
    source_repo=$(jj --repository "$source_root" config path --repo 2>/dev/null) || return 1
    registered_root=$(jj --repository "$source_root" workspace root --name "$name" 2>/dev/null) || return 1
    [[ ! -L "$registered_root" ]] || return 1
    registered_root=$(_canonical_directory "$registered_root") || return 1

    target_root=$(jj --repository "$registered_root" workspace root 2>/dev/null) || return 1
    target_root=$(_canonical_directory "$target_root") || return 1
    target_repo=$(jj --repository "$registered_root" config path --repo 2>/dev/null) || return 1

    [[ "$registered_root" == "$target_root" && "$source_repo" == "$target_repo" ]] || return 1
    # jj resolves registered paths through symlinks. A replaced path must not
    # redirect removal into another workspace in the same repository.
    local roots other_name other_root
    roots=$(jj --repository "$source_root" workspace list -T 'name ++ "\t" ++ root ++ "\n"' 2>/dev/null) || return 1
    while IFS=$'\t' read -r other_name other_root; do
        if [[ "$other_name" != "$name" && "$other_root" == "$registered_root" ]]; then
            return 1
        fi
    done <<< "$roots"
    printf '%s\n' "$registered_root"
}

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
    if ! workspace_dir=$(_verified_workspace_root "$name"); then
        _error "Cannot safely inspect workspace '$name'; nothing was removed"
        return 1
    fi

    # Check for uncommitted changes (unless --force)
    local has_changes=false
    if ! $force; then
        local diff_output
        if ! diff_output=$(jj diff --summary -r "@" --repository "$workspace_dir" 2>/dev/null); then
            _error "Cannot inspect changes in workspace '$name'; nothing was removed"
            return 1
        fi
        if [[ -n "$diff_output" ]]; then
            has_changes=true
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
    local current_root
    current_root=$(jj workspace root 2>/dev/null) || {
        _error "Cannot inspect the current workspace; nothing was removed"
        return 1
    }
    current_root=$(_canonical_directory "$current_root") || {
        _error "Cannot inspect the current workspace; nothing was removed"
        return 1
    }
    if [[ "$current_root" == "$workspace_dir" ]]; then
        local main_dir
        main_dir=$(jj workspace root --name "default" 2>/dev/null) || {
            _error "Cannot locate the default workspace; nothing was removed"
            return 1
        }
        cd "$main_dir" || return 1
        _info "Switched to default workspace"
    fi

    # Remove with spinner
    if ! gum spin --spinner dot --title "Removing workspace..." -- \
        jj workspace forget "$name"; then
        _error "Failed to forget workspace '$name'; its directory was preserved"
        return 1
    fi

    # Recheck the on-disk repository after forgetting to narrow the window in
    # which the path could be replaced before recursive deletion.
    local verified_after_forget
    if ! verified_after_forget=$(_verified_workspace_root_after_forget "$workspace_dir"); then
        _error "Workspace path changed during removal; directory was preserved"
        return 1
    fi

    # Clean up the directory
    if [[ -d "$verified_after_forget" ]]; then
        rm -rf -- "$verified_after_forget"
    fi

    _success "Removed workspace '$name'"
}

_verified_workspace_root_after_forget() {
    local expected_root="$1"
    local target_root

    [[ ! -L "$expected_root" ]] || return 1
    target_root=$(jj --repository "$expected_root" workspace root 2>/dev/null) || return 1
    target_root=$(_canonical_directory "$target_root") || return 1
    [[ "$target_root" == "$expected_root" ]] || return 1

    # The invoking workspace and forgotten workspace must still resolve to the
    # same repository. This remains queryable until the directory is deleted.
    local source_repo target_repo
    source_repo=$(jj config path --repo 2>/dev/null) || return 1
    target_repo=$(jj --repository "$expected_root" config path --repo 2>/dev/null) || return 1
    [[ "$source_repo" == "$target_repo" ]] || return 1
    printf '%s\n' "$target_root"
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
