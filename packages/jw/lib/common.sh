# jw common utilities
# Sourced by all jw commands

# =============================================================================
# Configuration
# =============================================================================

# Default workspace path pattern: ../repo--name
: "${JW_WORKSPACE_PATH:=../{repo}--{name}}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly DIM='\033[0;2m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Symbols
readonly CHECK="✓"
readonly CROSS="✗"
readonly ARROW="→"
readonly DOT="●"

# =============================================================================
# Output Utilities
# =============================================================================

_error() {
    echo -e "${RED}error:${NC} $*" >&2
}

_warn() {
    echo -e "${YELLOW}warning:${NC} $*" >&2
}

_info() {
    echo -e "${DIM}$*${NC}"
}

_success() {
    echo -e "${GREEN}${CHECK}${NC} $*"
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

# Execute command after switching
_execute_command() {
    local cmd="$1"
    
    case "$cmd" in
        claude)
            echo "Starting Claude..."
            exec claude
            ;;
        opencode|oc)
            echo "Starting OpenCode..."
            exec opencode
            ;;
        code|vscode)
            echo "Opening in VS Code..."
            code .
            ;;
        nvim|vim)
            echo "Opening in Neovim..."
            exec nvim
            ;;
        zed)
            echo "Opening in Zed..."
            zed .
            ;;
        *)
            echo "Executing: $cmd"
            exec $cmd
            ;;
    esac
}
