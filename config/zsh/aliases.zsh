# Navigation aliases (not in nix config)
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'
alias cdg='cd `git rev-parse --show-toplevel`'

# Utilities not in nix config
alias clr=clear
alias wget='wget -c'
alias path='echo -e ${PATH//:/\\n}'
alias ports='netstat -tulanp'
alias mk=make
alias gurl='curl --compressed'
alias shutdown='sudo shutdown'
alias reboot='sudo reboot'

# rcp variants (base rcp alias is in nix config)
alias rcpd='rcp --delete --delete-after'
alias rcpu='rcp --chmod=go='
alias rcpdu='rcpd --chmod=go='

# Linux-only aliases
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

# Beads global search
alias bdf='bd-find-all'          # Search from current dir (fallback to ~)
alias bdfa='bd-find-all --all'   # Search from home dir

# Claude Code
alias cc="claude --dangerously-skip-permissions"
