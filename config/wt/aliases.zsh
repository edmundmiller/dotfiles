# Worktrunk aliases for parallel AI agent workflows
#
# Worktrunk simplifies git worktree management for running multiple AI agents
# (Claude, OpenCode, etc.) in parallel on different branches.

if command -v wt >/dev/null 2>&1; then
  # Core commands - list, switch, merge, remove
  alias wtl='wt list'
  alias wts='wt switch'
  alias wtm='wt merge'
  alias wtr='wt remove'
  alias wtc='wt config'
  
  # Enhanced list view with CI status and full diffstat
  alias wtst='wt list --full'
  
  # Create worktree shortcuts
  alias wtcr='wt switch -c'                    # Create branch + worktree + switch
  alias wtcc='wt switch -c -x claude'          # Create + switch + launch Claude
  alias wtco='wt switch -c -x opencode'        # Create + switch + launch OpenCode
  
  # Interactive selection with fzf-like picker
  alias wtsel='wt select'
  
  # Config management
  alias wtcfg='wt config show'                 # Show config and diagnostics
  alias wtcfg-edit='$EDITOR ~/.config/worktrunk/config.toml'  # Edit user config
  alias wtcfg-proj='$EDITOR .config/wt.toml'   # Edit project config (if exists)
  
  # Quick navigation shortcuts
  alias wtb='wt switch -'                      # Switch to previous worktree
  alias wtmain='wt switch main || wt switch master'  # Jump to main worktree
  
  # Worktree step commands (commit workflow)
  alias wtstep='wt step'
  alias wtcom='wt step commit'                 # Commit changes
  alias wtsq='wt step squash'                  # Squash last N commits
  
  # Hook management
  alias wthook='wt hook'
  alias wthook-ls='wt hook list'               # List project hooks
  alias wthook-run='wt hook run'               # Manually run a hook
fi
