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
  
  # JSON output for scripting/dashboards
  alias wtj='wt list --format=json'
  
  # Stacked branches - branch from current HEAD instead of main
  alias wtstack='wt switch -c --base=@'        # Create branch from current HEAD
  
  # Agent handoffs - spawn worktree with agent in background tmux session
  # This lets one Claude session hand off work to another that runs in parallel
  alias wtcc-bg='_wt_spawn_agent_tmux claude'
  alias wtco-bg='_wt_spawn_agent_tmux opencode'
  
  # Helper function for spawning agents in background tmux sessions
  # Usage: wtcc-bg <branch-name> [prompt]
  # Example: wtcc-bg fix-auth-bug "Fix authentication timeout issue"
  function _wt_spawn_agent_tmux() {
    local agent="$1"
    shift
    local branch="$1"
    shift
    local prompt="$*"
    
    if [[ -z "$branch" ]]; then
      echo "Error: branch name required"
      echo "Usage: wtcc-bg <branch> [prompt]"
      return 1
    fi
    
    # Check if tmux is available
    if ! command -v tmux >/dev/null 2>&1; then
      echo "Error: tmux not found. Install tmux or use wtcc/wtco instead."
      return 1
    fi
    
    # Build the command to run in tmux
    local cmd="wt switch --create \"$branch\" -x $agent"
    if [[ -n "$prompt" ]]; then
      cmd="$cmd -- \"$prompt\""
    fi
    
    # Spawn tmux session in background
    tmux new-session -d -s "$branch" "$cmd"
    
    echo "✨ Spawned $agent on branch '$branch' in background tmux session"
    echo "   Attach with: tmux attach -t $branch"
    echo "   List sessions: tmux ls"
    echo "   Kill session: tmux kill-session -t $branch"
  }
fi
