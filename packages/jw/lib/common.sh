# jw common utilities
# Sourced by all jw commands
# Uses gum for all styled output

# =============================================================================
# Configuration
# =============================================================================

# Default workspace path pattern: ../repo--name
JW_WORKSPACE_PATH="${JW_WORKSPACE_PATH:-../{repo\}--{name\}}"

# =============================================================================
# Output Utilities (gum-based)
# =============================================================================

_error() {
    gum style --foreground 196 --bold "error:" "$*" >&2
}

_warn() {
    gum style --foreground 214 --bold "warning:" "$*" >&2
}

_info() {
    gum style --faint "$*"
}

_success() {
    gum style --foreground 42 "✓ $*"
}

# Styled header for section titles
_header() {
    gum style --bold --foreground 212 "$*"
}

# Spinner wrapper for long operations
_spin() {
    local title="$1"
    shift
    gum spin --spinner dot --title "$title" -- "$@"
}

# Format markdown text
_format_md() {
    gum format <<<"$*"
}

# =============================================================================
# TTY Detection
# =============================================================================

# Check if running interactively (has TTY)
_is_interactive() {
    [[ -t 0 && -t 1 ]]
}

# Require TTY for interactive features, show usage hint if not
_require_tty() {
    local usage="$1"
    if ! _is_interactive; then
        _error "Interactive mode requires a terminal"
        _info "$usage"
        return 1
    fi
}

# =============================================================================
# Repository Utilities
# =============================================================================

# Get repo root
_repo_root() {
    jj workspace root 2>/dev/null || jj root 2>/dev/null || pwd
}

# Get repo name from current directory
_repo_name() {
    local root
    root="$(_repo_root)"
    basename "$root"
}

# Compute workspace path from pattern
# Supports: {repo}, {name}
_workspace_path() {
    local name="$1"
    local repo
    repo="$(_repo_name)"
    local root
    root="$(_repo_root)"

    local path="$JW_WORKSPACE_PATH"
    path="${path//\{repo\}/$repo}"
    path="${path//\{name\}/$name}"

    # If path is relative, make it relative to repo root
    if [[ "$path" != /* ]]; then
        path="$root/$path"
    fi

    echo "$path"
}

# Get current workspace name from path
_current_workspace() {
    local cwd worktree
    cwd="$(pwd)"
    worktree="$(basename "$cwd")"

    # Check if we're in a workspace (format: repo--name)
    if [[ "$worktree" == *--* ]]; then
        echo "${worktree#*--}"
    else
        echo "default"
    fi
}

# Check if workspace exists
_workspace_exists() {
    local name="$1"
    jj workspace list -T 'name ++ "\n"' 2>/dev/null | grep -qx "$name"
}

# Get workspace path from name
_workspace_dir() {
    local name="$1"
    if [[ "$name" == "default" ]]; then
        _repo_root
    else
        _workspace_path "$name"
    fi
}

# List all workspace names
_workspace_names() {
    jj workspace list -T 'name ++ "\n"' 2>/dev/null
}

# Execute command after switching
_execute_command() {
    local cmd="$1"

    case "$cmd" in
    claude)
        _info "Starting Claude..."
        exec claude
        ;;
    opencode | oc)
        _info "Starting OpenCode..."
        exec opencode
        ;;
    code | vscode)
        _info "Opening in VS Code..."
        code .
        ;;
    nvim | vim)
        _info "Opening in Neovim..."
        exec nvim
        ;;
    zed)
        _info "Opening in Zed..."
        zed .
        ;;
    *)
        _info "Executing: $cmd"
        exec $cmd
        ;;
    esac
}
