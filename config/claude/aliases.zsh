# Claude Code worktree automation functions

# Main function to create a worktree and start Claude Code session
function claude-wt() {
    local name="${1}"
    local branch="${2:-$(git branch --show-current 2>/dev/null)}"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "Error: Not in a git repository"
        return 1
    fi
    
    # Get the repository root
    local repo_root=$(git rev-parse --show-toplevel)
    local repo_name=$(basename "$repo_root")
    
    # Generate worktree name
    if [[ -z "$name" ]]; then
        local worktree_name="claude-${branch//\//-}-${timestamp}"
    else
        local worktree_name="claude-${name}-${timestamp}"
    fi
    
    # Create worktrees directory if it doesn't exist
    local worktree_base="${repo_root}/../worktrees"
    if [[ ! -d "$worktree_base" ]]; then
        echo "Creating worktrees directory at $worktree_base"
        mkdir -p "$worktree_base"
    fi
    
    local worktree_path="${worktree_base}/${repo_name}/${worktree_name}"
    
    echo "Creating worktree: ${worktree_name}"
    echo "  From branch: ${branch}"
    echo "  At path: ${worktree_path}"
    
    # Create the worktree
    if [[ -n "$2" ]]; then
        # Specific branch was provided
        git worktree add "$worktree_path" "$branch" || return 1
    else
        # Create from current branch with new branch name
        git worktree add -b "$worktree_name" "$worktree_path" || return 1
    fi
    
    # Navigate to the new worktree
    cd "$worktree_path"
    
    # Start Claude Code session
    echo "Starting Claude Code in ${worktree_path}"
    claude
}

# Alias for convenience
alias cwt='claude-wt'

# Helper function to list and clean up Claude worktrees
function claude-wt-list() {
    echo "Claude worktrees:"
    git worktree list | grep -E "claude-.*-[0-9]{8}-[0-9]{6}" | while read -r line; do
        local path=$(echo "$line" | awk '{print $1}')
        local branch=$(echo "$line" | awk '{print $3}' | tr -d '[]')
        local name=$(basename "$path")
        echo "  $name -> $branch"
        echo "    Path: $path"
    done
}

# Function to remove Claude worktrees
function claude-wt-clean() {
    local pattern="${1:-claude-}"
    
    echo "Finding Claude worktrees matching pattern: $pattern"
    
    local worktrees=$(git worktree list | grep -E "${pattern}.*-[0-9]{8}-[0-9]{6}" | awk '{print $1}')
    
    if [[ -z "$worktrees" ]]; then
        echo "No Claude worktrees found"
        return 0
    fi
    
    echo "Found worktrees:"
    echo "$worktrees" | while read -r path; do
        echo "  - $(basename $path) at $path"
    done
    
    echo ""
    read "confirm?Remove these worktrees? (y/N): "
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "$worktrees" | while read -r path; do
            echo "Removing worktree: $(basename $path)"
            git worktree remove "$path" --force 2>/dev/null || git worktree remove "$path"
        done
        echo "Cleanup complete"
        
        # Prune any stale worktree references
        git worktree prune
    else
        echo "Cleanup cancelled"
    fi
}

# Function to jump to an existing Claude worktree
function claude-wt-cd() {
    local pattern="${1:-}"
    
    local worktrees=$(git worktree list | grep -E "claude-.*-[0-9]{8}-[0-9]{6}" | awk '{print $1}')
    
    if [[ -z "$worktrees" ]]; then
        echo "No Claude worktrees found"
        return 1
    fi
    
    if [[ -n "$pattern" ]]; then
        # Filter by pattern
        local matched=$(echo "$worktrees" | grep -i "$pattern" | head -1)
        if [[ -n "$matched" ]]; then
            cd "$matched"
            echo "Changed to worktree: $(basename $matched)"
        else
            echo "No worktree matching '$pattern' found"
            return 1
        fi
    else
        # Interactive selection using fzf if available
        if command -v fzf >/dev/null; then
            local selected=$(echo "$worktrees" | fzf --prompt="Select worktree: " --height=40% --reverse)
            if [[ -n "$selected" ]]; then
                cd "$selected"
                echo "Changed to worktree: $(basename $selected)"
            fi
        else
            # List available worktrees
            echo "Available Claude worktrees:"
            echo "$worktrees" | while read -r path; do
                echo "  $(basename $path) -> $path"
            done
            echo ""
            echo "Usage: claude-wt-cd <pattern>"
        fi
    fi
}

# Aliases for convenience
alias cwl='claude-wt-list'
alias cwc='claude-wt-clean'
alias cwd='claude-wt-cd'