#!/usr/bin/env zsh

# =============================================================================
# Lazy Loading for JJ Completions (~50ms startup savings)
# =============================================================================
# Based on: https://willhbr.net/2025/01/06/lazy-load-command-completions-for-a-faster-shell-startup/
# JJ completions are expensive to load. This wrapper loads them on first use.

function jj {
  if [[ -z $_JJ_LOADED ]]; then
    source <(command jj util completion zsh)
    _JJ_LOADED=1
  fi
  command jj --config "ui.default-command=[\"log\"]" --config "width=$(( COLUMNS > 0 ? COLUMNS : 80 ))" "$@"
}

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
alias jdiff='jj diff'  # Show differences
alias jshow='jj show'  # Show commit details
alias jmdiff='jj mdiff' # Diff from trunk (what will be in PR)

# Restore (powerful file/change management)
alias jres='jj restore'      # Discard changes (safer than abandon)
alias jresi='jj restore -i'  # Interactively discard parts of changes

# Log variants (default is AI-optimized for agents)
# jl shows hint about human-friendly option
jl() {
    jj log "$@"
    # Show hint in dim gray (only if interactive terminal, not piped)
    [[ -t 1 ]] && print -P "%F{8}# Tip: 'jj lh' for human-friendly, 'jj lc' for visual%f"
}
alias jlh='jj lh'      # Human-friendly log
alias jlc='jj lc'      # Visual credits_roll log

# Operations
alias jr='jj rebase'   # Rebase commits
alias jb='jj bookmark' # Manage bookmarks
alias jsync='jj sync'  # Fetch all remotes
alias jevolve='jj evolve'  # Rebase onto trunk
alias jpullup='jj pullup'  # Pull all mutable commits onto trunk

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
# JJ Workspace (jw) - Worktrunk-inspired workspace management
# =============================================================================
# See: jw help
# Full tool at: bin/jw

# Core jw aliases (matching worktrunk's wt aliases)
alias jws='jw switch'       # Switch to workspace
alias jwl='jw list'         # List workspaces with status
alias jwr='jw remove'       # Remove workspace
alias jwm='jw merge'        # Merge workspace to trunk

# Quick create + launch agent
alias jwc='jw switch -c -x claude'    # Create + Claude
alias jwo='jw switch -c -x opencode'  # Create + OpenCode

# Legacy aliases (for backward compatibility)
alias ja='jw switch -c'     # Create workspace (old: ja)
alias jwd='jw remove'       # Remove workspace (old: jwd)
