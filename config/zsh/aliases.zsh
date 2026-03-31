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

alias ssc='sudo systemctl'

if command -v eza >/dev/null; then
    alias eza="eza --group-directories-first --git"
    alias l="eza -blF"
    alias ll="eza -abghilmu"
    alias llmod='ll --sort=modified'
    alias la="LC_COLLATE=C eza -ablF"
    alias lt='eza --tree --level=2 --long --icons --git'
    alias lta='lt -a'
    alias tree='eza --tree'
fi

if (($ + commands[fasd])); then
    # fuzzy completion with 'z' when called without args
    unalias z 2>/dev/null || true
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

# fzf + bat preview (from omarchy)
alias ff="fzf --preview 'bat --style=numbers --color=always {}'"
eff() { $EDITOR $(ff); }

# Compression (from omarchy)
compress() { tar -czf "${1%/}.tar.gz" "${1%/}"; }
alias decompress="tar -xzf"

# SSH port forwarding helpers (from omarchy)
fip() {
  [[ $# -lt 2 ]] && echo "Usage: fip <host> <port1> [port2] ..." && return 1
  local host="$1"; shift
  for port in "$@"; do
    ssh -f -N -L "$port:localhost:$port" "$host" && echo "Forwarding localhost:$port → $host:$port"
  done
}
dip() {
  [[ $# -eq 0 ]] && echo "Usage: dip <port1> [port2] ..." && return 1
  for port in "$@"; do
    pkill -f "ssh.*-L $port:localhost:$port" && echo "Stopped forwarding port $port" || echo "No forwarding on port $port"
  done
}
lip() { pgrep -af "ssh.*-L [0-9]+:localhost:[0-9]+" || echo "No active forwards"; }

# v/vi/nv defined in modules/editors/vim.nix

alias kb=keybase
alias exe=exercism
alias ydl=youtube-dl
alias ydl-aac='youtube-dl --extract-audio --audio-format aac'
alias ydl-m4a='youtube-dl --extract-audio --audio-format m4a'
alias ddg=duckduckgo
alias bt=transmission-remote
alias tb="nc termbin.com 9999"

# Global issue search
alias brf='br-find-all'          # Search from current dir (fallback to ~)
alias brfa='br-find-all --all'   # Search from home dir
# Compatibility aliases for the older bd-* helper names.
alias bdf='br-find-all'
alias bdfa='br-find-all --all'

# Agent launch helpers: avoid bare git worktree hubs as cwd
_agent_safe_cwd() {
    local resolver="${DOTFILES_BIN:-$HOME/.config/dotfiles/bin}/git-worktree-cwd"
    [[ -x "$resolver" ]] || resolver="$HOME/.config/dotfiles/bin/git-worktree-cwd"
    if [[ -x "$resolver" ]]; then
        "$resolver" "$PWD"
    else
        echo "$PWD"
    fi
}

# Claude Code
cc() {
    local safe_cwd
    safe_cwd=$(_agent_safe_cwd) || return 1
    cd "$safe_cwd" || return 1
    command claude --dangerously-skip-permissions "$@"
}

# Codex
cdx() {
    local safe_cwd
    safe_cwd=$(_agent_safe_cwd) || return 1
    cd "$safe_cwd" || return 1
    command codex "$@"
}

# difi: pipe git diff with --no-ext-diff to bypass difft; TERM=ghostty breaks the renderer
difi() {
  local target="${1:-HEAD}"
  git diff --no-ext-diff --color=always "$target" | TERM=xterm-256color command difi
}
