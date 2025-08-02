# Bugwarrior aliases for fish shell

# Main bugwarrior commands
alias bw="bugwarrior-pull"
alias bw-dry="bugwarrior-pull --dry-run"
alias bw-sync="bugwarrior-sync"

# Show bugwarrior-related tasks in taskwarrior
alias bw-tasks="task project:bugwarrior list"
alias bw-jira="task +jira list"
alias bw-github="task +github list"
alias bw-seqera="task +seqera list"

# Bugwarrior logs
alias bw-log="tail -f ~/.local/share/bugwarrior/sync.log"
alias bw-errors="tail -f ~/.local/share/bugwarrior/launchd-error.log"

# Setup commands
alias bw-setup="setup-bugwarrior"
alias bw-creds="setup-bugwarrior-credentials"
alias bw-auto="setup-bugwarrior-sync"