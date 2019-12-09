### ReDefs
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

alias mkdir='mkdir -p'
alias wget='wget -c'
alias rg='noglob rg'
alias bc='bc -lq'

alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

### convenience
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

alias q=exit
alias clr=clear
alias sudo='sudo '

if command -v exa >/dev/null; then
	alias exa='exa --group-directories-first'
	alias l='exa -1'
	alias ll='exa -l'
	alias la='LC_COLLATE=C exa -la'
else
	alias l='ls -1'
	alias ll='ls -l'
fi

alias mk=make
alias rcp='rsync -vaP --delete'
alias rmirror='rsync -rtvu --delete'
alias gurl='curl --compressed'

alias y='xclip -selection clipboard -in'
alias p='xclip -selection clipboard -out'

alias sc=systemctl
alias ssc='sudo systemctl'

alias nix-env='NIXPKGS_ALLOW_UNFREE=1 nix-env'
alias ne=nix-env
alias nc=nix-channel
alias ngc=nix-garbage-collect
alias nre="sudo nixos-rebuild -I config=$DOTFILES -I packages=$DOTFILES/packages"
alias ns=nix-shell

### Tools
autoload -U zmv

# Convenience
alias kb=keybase
alias mk=make
alias exe=exercism
alias ydl=youtube-dl
alias ydl-aac='youtube-dl --extract-audio --audio-format aac'
alias ydl-m4a='youtube-dl --extract-audio --audio-format m4a'
alias ddg=duckduckgo
alias bt=transmission-remote

take() {
	mkdir "$1" && cd "$1"
}
compdef take=mkdir

zman() {
	PAGER="less -g -s '+/^       "$1"'" man zshall
}

r() {
	local time=$1
	shift
	sched "$time" "notify-send --urgency=critical 'Reminder' '$@'; ding"
}
compdef r=sched
