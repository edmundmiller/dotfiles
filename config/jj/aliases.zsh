#!/usr/bin/env zsh

# Terminal width wrapper for better output
alias jj="jj --config width=$(tput cols)"

# Core workflow commands
alias jn='jj new'      # Start new work
alias js='jj squash'   # Squash changes into parent
alias jd='jj describe' # Describe current commit
alias je='jj edit'     # Edit a commit

# Navigation
alias jp='jj prev'     # Go to previous commit
alias jnx='jj next'    # Go to next commit

# Inspection
alias jst='jj status'  # Show status
alias jl='jj log'      # Show log
alias jdiff='jj diff'  # Show differences
alias jshow='jj show'  # Show commit details

# Operations
alias jr='jj rebase'   # Rebase commits
alias jb='jj bookmark' # Manage bookmarks

# Open diff in neovim (PR preview) - wraps jj nd
jnd() {
    jj nd "$@"
}

# Workflow helpers

# Describe and create new commit
jnew() {
    jj describe -m "${1:-WIP}" && jj new
}

# Quick squash with message
jsquash() {
    if [[ -n "$1" ]]; then
        jj squash -m "$1"
    else
        jj squash
    fi
}

# Clean up jj history
jclean() {
    echo "Cleaning up empty commits..."
    jj tidy
    echo "Current work status:"
    jj work
}

# Show only active work
jwork() {
    jj log -r 'mine() & ~empty() & ~immutable()'
}

# Quick abandon current if empty and go to previous
jback() {
    if [[ -z $(jj diff) ]]; then
        jj abandon @ && jj edit @-
    else
        echo "Current commit has changes, use 'jj abandon' explicitly if you want to lose them"
    fi
}

# =============================================================================
# JJ Workspace Helpers (ported from DHH's git worktree script)
# =============================================================================
# ja: Create a new workspace for parallel work (e.g., AI agent)
# jd: Remove a workspace when done

# Create a new jj workspace
# Usage: ja [workspace-name]
# Creates workspace at ../repo--name with same parent commits as current @
ja() {
    if [[ -z "$1" ]]; then
        echo "Usage: ja <workspace-name>"
        echo "Creates a new jj workspace for parallel work"
        return 1
    fi

    local name="$1"
    local base
    base="$(basename "$PWD")"
    local workspace_path="../${base}--${name}"

    # Create workspace with same parent as current working copy
    if jj workspace add --name "$name" "$workspace_path"; then
        # Trust mise/direnv if present
        [[ -f "$workspace_path/.mise.toml" ]] && mise trust "$workspace_path" 2>/dev/null
        [[ -f "$workspace_path/.envrc" ]] && direnv allow "$workspace_path" 2>/dev/null
        
        echo "Created workspace '$name' at $workspace_path"
        echo "Switch to it with: cd $workspace_path"
        cd "$workspace_path" || return 1
    fi
}

# Remove a jj workspace (run from within the workspace directory)
# Usage: jwd (from within workspace) or jwd <workspace-name> (from main repo)
jwd() {
    local workspace_name

    # If argument provided, use it as workspace name
    if [[ -n "$1" ]]; then
        workspace_name="$1"
    else
        # Extract workspace name from current directory
        local cwd worktree root
        cwd="$(pwd)"
        worktree="$(basename "$cwd")"
        
        # Split on first `--`
        root="${worktree%%--*}"
        workspace_name="${worktree#*--}"
        
        # Protect against accidentally nuking a non-workspace directory
        if [[ "$root" == "$worktree" ]]; then
            echo "Error: Not in a workspace directory (expected format: repo--workspace)"
            echo "Run from within a workspace dir, or specify workspace name: jwd <name>"
            return 1
        fi
    fi

    # Confirm before removing
    if command -v gum &>/dev/null; then
        gum confirm "Remove workspace '$workspace_name'?" || return 0
    else
        echo -n "Remove workspace '$workspace_name'? [y/N] "
        read -r confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || return 0
    fi

    # If we're in the workspace, cd to parent first
    local cwd worktree root
    cwd="$(pwd)"
    worktree="$(basename "$cwd")"
    root="${worktree%%--*}"
    
    if [[ "${worktree#*--}" == "$workspace_name" ]]; then
        cd "../$root" || return 1
    fi

    # Remove the workspace
    jj workspace forget "$workspace_name"
    
    # Clean up the directory if it exists
    local workspace_dir="../${root}--${workspace_name}"
    if [[ -d "$workspace_dir" ]]; then
        rm -rf "$workspace_dir"
        echo "Removed workspace directory: $workspace_dir"
    fi
    
    echo "Workspace '$workspace_name' removed"
}

# List all workspaces
alias jws='jj workspace list'
