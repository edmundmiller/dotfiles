# Worktrunk aliases - parallel AI agent workflows
# Prefix: w (not wt - saves a keystroke)
# Default agent: pi

if command -v wt >/dev/null 2>&1; then
  # Core (daily drivers)
  alias w='wt list'                            # Just `w` to see worktrees
  alias ws='wt switch'                         # ws main, ws feature/foo
  alias wm='wt merge'                          # Merge current worktree
  alias wr='wt remove'                         # wr feature/done
  alias wf='wt list --full'                    # Full view: CI, diffstat
  
  # Create worktree (pi is default agent)
  alias wc='wt switch -c -x pi'                # wc feature/new → creates + launches pi
  alias wc!='wt switch -c'                     # wc! feature/new → no agent
  alias wcc='wt switch -c -x claude'           # wcc feature/auth
  alias wco='wt switch -c -x opencode'         # wco fix/bug-123
  
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
