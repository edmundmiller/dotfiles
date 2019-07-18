AUTOPAIR_INHIBIT_INIT=1

# source $ZDOTDIR/prompt.zsh
# source $ZDOTDIR/config.zsh
# source $ZDOTDIR/completion.zsh
# source $ZDOTDIR/keybinds.zsh

#
# autoload -Uz compinit && compinit -d $ZSH_CACHE/zcompdump
source $ZDOTDIR/zsh_plugins.sh

#
export _FASD_DATA="$XDG_CACHE_HOME/fasd"
export _FASD_VIMINFO="$XDG_CACHE_HOME/viminfo"
# _cache fasd --init posix-alias zsh-{hook,{c,w}comp{,-install}}
# autopair-init

for file in $XDG_CONFIG_HOME/zsh/rc.d/aliases.*.zsh(N); do
  source $file
done
