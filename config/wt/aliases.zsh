# Worktrunk aliases - parallel AI agent workflows
# Prefix: w (not wt - saves a keystroke)
# Default agent: pi + lazygit split

if command -v wt >/dev/null 2>&1; then
  # Core (daily drivers)
  alias w='wt list'                            # Just `w` to see worktrees
  alias ws='wt switch'                         # ws main, ws feature/foo
  alias wm='wt merge'                          # Merge current worktree
  alias wr='wt remove'                         # wr feature/done
  alias wf='wt list --full'                    # Full view: CI, diffstat
  
  # Create worktree + open pi + git TUI split
  # Usage: wc feature/new [prompt]
  wc() {
    local branch="$1"; shift
    [[ -z "$branch" ]] && { echo "usage: wc <branch> [prompt]"; return 1; }
    wt switch -c "$branch"
    # Open git TUI in right split (30% width), pi in main pane
    tmux split-window -h -l 30% "$TMUX_HOME/open-git-tui.sh"
    tmux select-pane -L
    pi "$@"
  }
  
  # Variants
  wc!() { wt switch -c "$@"; }                 # No agent, no split
  wcc() {                                      # Claude + git split
    local branch="$1"; shift
    [[ -z "$branch" ]] && { echo "usage: wcc <branch> [prompt]"; return 1; }
    wt switch -c "$branch"
    tmux split-window -h -l 30% "$TMUX_HOME/open-git-tui.sh"
    tmux select-pane -L
    claude "$@"
  }
  wco() {                                      # OpenCode + git split
    local branch="$1"; shift
    [[ -z "$branch" ]] && { echo "usage: wco <branch> [prompt]"; return 1; }
    wt switch -c "$branch"
    tmux split-window -h -l 30% "$TMUX_HOME/open-git-tui.sh"
    tmux select-pane -L
    opencode "$@"
  }
  
  # Navigation
  alias w-='wt switch -'                       # Previous worktree
  alias ww='wt select'                         # Interactive picker
  
  # Commit workflow  
  alias wcm='wt step commit'                   # Commit with LLM message
  alias wsq='wt step squash'                   # Squash commits
  
  # Background agent spawn (for handoffs)
  wbg() {
    local agent="${1:-pi}" branch="$2"; shift 2
    [[ -z "$branch" ]] && { echo "usage: wbg [agent] <branch> [prompt]"; return 1; }
    tmux new-session -d -s "$branch" "wt switch -c $branch -x $agent -- '$*'"
    echo "✨ $agent on '$branch' | attach: tmux a -t $branch"
  }
fi
