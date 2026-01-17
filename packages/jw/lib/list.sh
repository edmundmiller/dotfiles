# jw list command

cmd_list() {
    local full=false
    local format="table"

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --full | -f)
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

    _list_table "$full" "$current_ws" "$repo_root"
}

_list_table() {
    local full="$1"
    local current_ws="$2"
    local repo_root="$3"

    local count=0
    local dirty_count=0
    local ahead_count=0

    # Build CSV data for gum table
    local csv_data=""

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
        local status_display=""
        local ahead=""

        if [[ -d "$path" ]]; then
            # Check for uncommitted changes
            local diff_output
            if diff_output=$(jj diff --summary -r "@" --at-op=@ --ignore-working-copy --repository "$path" 2>/dev/null); then
                if [[ -n "$diff_output" ]]; then
                    status="dirty"
                    status_display="● modified"
                    dirty_count=$((dirty_count + 1))
                else
                    status="clean"
                    status_display="✓ clean"
                fi
            else
                status="?"
                status_display="? unknown"
            fi

            # Count commits ahead of trunk
            if $full; then
                local ahead_num
                ahead_num=$(jj log -r "@ ~ trunk()" --no-graph -T 'commit_id ++ "\n"' --repository "$path" 2>/dev/null | grep -c . || echo "0")
                if [[ "$ahead_num" -gt 0 ]]; then
                    ahead="↑$ahead_num"
                    ahead_count=$((ahead_count + 1))
                fi
            fi
        else
            status="missing"
            status_display="✗ missing"
        fi

        # Current indicator
        local display_name="$name"
        if [[ "$name" == "$current_ws" ]]; then
            display_name="* $name"
        else
            display_name="  $name"
        fi

        # Format path for display (relative if possible)
        local display_path="$path"
        if [[ "$path" == "$HOME"* ]]; then
            display_path="~${path#$HOME}"
        fi

        # Add row to CSV
        if $full; then
            csv_data+="${display_name},${status_display},${ahead},${display_path}"$'\n'
        else
            csv_data+="${display_name},${status_display},${display_path}"$'\n'
        fi

    done < <(jj workspace list -T 'name ++ "\n"' 2>/dev/null)

    # Render table with gum
    if [[ -n "$csv_data" ]]; then
        if $full; then
            echo -e "WORKSPACE,STATUS,AHEAD,PATH\n${csv_data}" | gum table \
                --border rounded \
                --print
        else
            echo -e "WORKSPACE,STATUS,PATH\n${csv_data}" | gum table \
                --border rounded \
                --print
        fi
    fi

    # Summary
    echo ""
    local summary="$count workspace"
    [[ $count -ne 1 ]] && summary+="s"

    if [[ $dirty_count -gt 0 ]]; then
        summary+=", $dirty_count modified"
    fi
    if [[ $ahead_count -gt 0 ]]; then
        summary+=", $ahead_count ahead"
    fi

    _info "$summary"
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
            if diff_output=$(jj diff --summary -r "@" --repository "$path" 2>/dev/null); then
                [[ -n "$diff_output" ]] && has_changes=true
            fi

            if $full; then
                ahead=$(jj log -r "@ ~ trunk()" --no-graph -T 'commit_id ++ "\n"' --repository "$path" 2>/dev/null | grep -c . || echo "0")
            fi
        fi

        printf '    {"name": "%s", "path": "%s", "current": %s, "has_changes": %s, "ahead": %d}' \
            "$name" "$path" "$is_current" "$has_changes" "$ahead"
    done < <(jj workspace list -T 'name ++ "\n"' 2>/dev/null)

    echo ""
    echo "  ]"
    echo "}"
}

cmd_list_help() {
    gum format <<'EOF'
# jw list

List all workspaces with their status.

## Usage

```
jw list [flags]
```

## Flags

| Flag | Description |
|------|-------------|
| `--full, -f` | Include ahead/behind counts |
| `--json` | Output as JSON (for scripting) |

## Status Indicators

| Symbol | Meaning |
|--------|---------|
| `*` | Current workspace |
| `✓ clean` | No uncommitted changes |
| `● modified` | Has uncommitted changes |
| `✗ missing` | Directory not found |
| `↑N` | N commits ahead of trunk |

## Examples

```bash
# Basic list
jw list

# With ahead counts
jw list --full

# JSON for scripting
jw list --json | jq '.workspaces[] | select(.has_changes)'
```
EOF
}
