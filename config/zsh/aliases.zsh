alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'
alias cdg='cd `git rev-parse --show-toplevel`'

alias q=exit
alias clr=clear
alias sudo='sudo '
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -p'
alias wget='wget -c'
alias path='echo -e ${PATH//:/\\n}'
alias ports='netstat -tulanp'

alias mk=make
alias gurl='curl --compressed'

alias shutdown='sudo shutdown'
alias reboot='sudo reboot'

# An rsync that respects gitignore
rcp() {
    # -a = -rlptgoD
    #   -r = recursive
    #   -l = copy symlinks as symlinks
    #   -p = preserve permissions
    #   -t = preserve mtimes
    #   -g = preserve owning group
    #   -o = preserve owner
    # -z = use compression
    # -P = show progress on transferred file
    # -J = don't touch mtimes on symlinks (always errors)
    rsync -azPJ \
        --include=.git/ \
        --filter=':- .gitignore' \
        --filter=":- $XDG_CONFIG_HOME/git/ignore" \
        "$@"
}
compdef rcp=rsync
alias rcpd='rcp --delete --delete-after'
alias rcpu='rcp --chmod=go='
alias rcpdu='rcpd --chmod=go='

alias y='xclip -selection clipboard -in'
alias p='xclip -selection clipboard -out'

alias jc='journalctl -xe'
alias sc=systemctl

# Avante.nvim Zen Mode - Launch Neovim in Avante's Zen Mode for AI-powered coding
alias avante='nvim -c "lua vim.defer_fn(function()require(\"avante.api\").zen_mode()end, 100)"'
alias ssc='sudo systemctl'

if command -v eza >/dev/null; then
    alias eza="eza --group-directories-first --git"
    alias l="eza -blF"
    alias ll="eza -abghilmu"
    alias llmod='ll --sort=modified'
    alias la="LC_COLLATE=C eza -ablF"
    alias tree='eza --tree'
fi

if (($ + commands[fasd])); then
    # fuzzy completion with 'z' when called without args
    unalias z 2>/dev/null
    function z {
        [ $# -gt 0 ] && _z "$*" && return
        cd "$(_z -l 2>&1 | fzf --height 40% --nth 2.. --reverse --inline-info +s --tac --query "${*##-* }" | sed 's/^[0-9,.]* *//')"
    }
fi

autoload -U zmv

function take() {
    mkdir "$1" && cd "$1"
}
compdef take=mkdir

function zman() {
    PAGER="less -g -I -s '+/^       "$1"'" man zshall
}

# Create a reminder with human-readable durations, e.g. 15m, 1h, 40s, etc
function r() {
    local time=$1
    shift
    sched "$time" "notify-send --urgency=critical 'Reminder' '$@'; ding"
}
compdef r=sched

# Convenience
# Editor aliases
alias vi='nvim'
alias nv='nvim'

alias kb=keybase
alias exe=exercism
alias ydl=youtube-dl
alias ydl-aac='youtube-dl --extract-audio --audio-format aac'
alias ydl-m4a='youtube-dl --extract-audio --audio-format m4a'
alias ddg=duckduckgo
alias bt=transmission-remote
alias tb="nc termbin.com 9999"

# Jujutsu (jj) shortcuts
alias jj="jj --config width=$(tput cols)"
alias jn='jj new'      # Start new work
alias js='jj squash'   # Squash changes into parent
alias jd='jj describe' # Describe current commit
alias jl='jj log'      # Show log
alias jst='jj status'  # Show status
alias jp='jj prev'     # Go to previous commit
alias jnx='jj next'    # Go to next commit
alias je='jj edit'     # Edit a commit
alias jr='jj rebase'   # Rebase commits
alias jb='jj bookmark' # Manage bookmarks
alias jdiff='jj diff'  # Show differences
alias jshow='jj show'  # Show commit details
# Open diff in neovim (PR preview) - wraps jj nd
jnd() {
    jj nd "$@"
}

# JJ workflow helpers
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

# Claude Code
alias cc="claude --dangerously-skip-permissions"
