# Bugwarrior aliases for zsh

# Main bugwarrior commands
alias bw="bugwarrior-pull"
alias bw-dry="bugwarrior-pull --dry-run"

# Show bugwarrior-related tasks in taskwarrior
alias bw-tasks="task +bw list"
alias bw-linear="task +linear list"
alias bw-github="task +github list"

# Bugwarrior logs
alias bw-log="tail -f ~/.local/share/bugwarrior/pull.log"
alias bw-errors="tail -f ~/.local/share/bugwarrior/pull-error.log"
