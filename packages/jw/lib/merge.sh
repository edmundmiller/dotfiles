# jw merge command

cmd_merge() {
    local name=""
    local squash="" # empty means ask interactively

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --squash | -s)
            squash=true
            shift
            ;;
        --rebase | -r)
            squash=false
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

    # If no name, use current workspace or select interactively
    if [[ -z "$name" ]]; then
        name="$(_current_workspace)"

        if [[ "$name" == "default" ]]; then
            if _is_interactive; then
                local workspaces
                workspaces=$(jj workspace list -T 'name ++ "\n"' 2>/dev/null | grep -v '^default$')

                if [[ -z "$workspaces" ]]; then
                    _error "No workspaces to merge (only default exists)"
                    return 1
                fi

                name=$(echo "$workspaces" | gum filter \
                    --header "Select workspace to merge" \
                    --placeholder "Type to filter...")

                [[ -z "$name" ]] && {
                    _info "Cancelled"
                    return 0
                }
            else
                _error "Cannot merge the default workspace"
                _info "Usage: jw merge <workspace-name>"
                return 1
            fi
        fi
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

    # Get commits ahead of trunk
    local commits
    commits=$(jj log -r "${name}@ ~ trunk()" --no-graph -T 'change_id.short() ++ "\n"' --repository "$workspace_dir" 2>/dev/null)

    if [[ -z "$commits" ]]; then
        _warn "Workspace '$name' has no commits ahead of trunk"
        return 0
    fi

    local commit_count
    commit_count=$(echo "$commits" | grep -c .)

    _header "Merge Workspace: $name"
    echo ""
    gum style --foreground 240 "Commits ahead: $commit_count"

    # Show commit summary
    echo ""
    jj log -r "${name}@ ~ trunk()" --repository "$workspace_dir" 2>/dev/null | head -20

    # Ask for merge strategy if not specified
    if [[ -z "$squash" ]]; then
        if _is_interactive; then
            echo ""
            local strategy
            strategy=$(gum choose \
                --header "Select merge strategy" \
                --cursor "▶ " \
                "Rebase (keep individual commits)" \
                "Squash (combine into single commit)")

            [[ -z "$strategy" ]] && {
                _info "Cancelled"
                return 0
            }
            [[ "$strategy" == "Squash"* ]] && squash=true || squash=false
        else
            squash=false # default to rebase in non-interactive
        fi
    fi

    echo ""

    # Execute merge
    if [[ "$squash" == "true" ]]; then
        gum spin --spinner dot --title "Squashing commits..." -- \
            jj squash --from "${name}@-" --into "trunk()" --repository "$workspace_dir"
    else
        gum spin --spinner dot --title "Rebasing onto trunk..." -- \
            jj rebase -s "roots(${name}@ ~ trunk())" -d "trunk()" --repository "$workspace_dir"
    fi

    _success "Merged '$name' into trunk"

    # Show next steps
    echo ""
    gum format <<EOF
## Next Steps

\`\`\`bash
jj git push        # Push to remote
jw remove $name    # Clean up workspace
\`\`\`
EOF
}

cmd_merge_help() {
    gum format <<'EOF'
# jw merge

Merge workspace changes into trunk.

## Usage

```
jw merge [flags] [name]
```

## Flags

| Flag | Description |
|------|-------------|
| `--squash, -s` | Squash all commits into one |
| `--rebase, -r` | Rebase keeping individual commits |

## Interactive Mode

When no strategy flag is provided, prompts to choose between:
- **Rebase**: Keeps individual commits for detailed history
- **Squash**: Combines all commits into a single commit

## Examples

```bash
# Merge current workspace (interactive strategy)
jw merge

# Merge specific workspace
jw merge my-feature

# Force squash without prompt
jw merge -s my-feature

# Force rebase without prompt
jw merge -r my-feature
```

## Workflow

1. Complete work in workspace
2. Run `jw merge` to integrate with trunk
3. Push changes: `jj git push`
4. Clean up: `jw remove <name>`
EOF
}
