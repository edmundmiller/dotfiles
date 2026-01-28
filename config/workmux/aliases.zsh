# Workmux aliases
# Tmux-native git worktree manager

alias wm='workmux'
alias wml='workmux list'
alias wma='workmux add'
alias wmm='workmux merge'
alias wmr='workmux remove'
alias wmd='workmux dashboard'

# Quick patterns
alias wma-b='workmux add -b'        # Background (no switch)
alias wma-A='workmux add -A'        # Auto-name from prompt
alias wma-bA='workmux add -b -A'    # Background + auto-name

# Critique - review diffs in tmux popup
alias wmc='tmux popup -E -w 90% -h 90% "bunx critique"'
alias wmcr='tmux popup -E -w 90% -h 90% "bunx critique review"'  # AI-powered diff review

# Session-based workmux - see bin/wms (standalone script for agent compatibility)
# Session list - show all workmux sessions
alias wmsl='tmux list-sessions 2>/dev/null | grep -v "^attached"'
