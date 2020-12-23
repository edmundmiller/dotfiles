alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

alias q=exit
alias clr=clear
alias sudo='sudo '
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -p'
alias wget='wget -c'

alias mk=make
alias rcp='rsync -vaP --delete'
alias rmirror='rsync -rtvu --delete'
alias gurl='curl --compressed'

alias y='xclip -selection clipboard -in'
alias p='xclip -selection clipboard -out'

autoload -U zmv

take() {
	mkdir "$1" && cd "$1"
}
compdef take=mkdir

zman() {
	PAGER="less -g -I -s '+/^       "$1"'" man zshall
}

r() {
	local time=$1
	shift
	sched "$time" "notify-send --urgency=critical 'Reminder' '$@'; ding"
}
compdef r=sched

# Convenience
alias kb=keybase
alias mk=make
alias exe=exercism
alias ydl=youtube-dl
alias ydl-aac='youtube-dl --extract-audio --audio-format aac'
alias ydl-m4a='youtube-dl --extract-audio --audio-format m4a'
alias ddg=duckduckgo
alias bt=transmission-remote
