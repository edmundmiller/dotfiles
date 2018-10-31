unsetopt GLOBAL_RCS  # disable global zsh config; we'll handle it ourselves
source $(cd ${${(%):-%x}:A:h}/../.. && pwd -P)/env

# Move ZDOTDIR from $HOME to reduce dotfile pollution.
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export ZGEN_DIR="$XDG_CACHE_HOME/zgen"
export ZSH_CACHE="$XDG_CACHE_HOME/zsh"

# paths
typeset -gU cdpath fpath mailpath path
path=( $XDG_BIN_HOME $DOTFILES/bin $DOTFILES_DATA/*.topic/bin(N) $path )
fpath=( $ZDOTDIR/functions $XDG_BIN_HOME $fpath )

# envvars
export SHELL=$(command -v zsh)
export LANG=${LANG:-en_US.UTF-8}
export PAGER=less
export LESS='-R -i -w -M -z-4'
export LESSHISTFILE="$XDG_DATA_HOME/lesshst"
export PASSWORD_STORE_DIR="$XDG_DATA_HOME/password-store"

# DOOM
export PATH=/home/emiller/.emacs.d/bin:$PATH

# TODO Move to python
export PATH="/home/emiller/.anaconda3/bin:$PATH"
# initialize enabled topics
_load_all env.zsh

# TODO Fix node
PATH="$HOME/.node_modules/bin:$PATH"
export npm_config_prefix=~/.node_modules

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export GOPATH=$HOME/src/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
export PATH=~/bin:/home/emiller/.node_modules/bin:/home/emiller/.local/share/tmuxifier/bin:/home/emiller/.local/share/pyenv/shims:/home/emiller/.local/share/pyenv/bin:/home/emiller/.anaconda/bin:/home/emiller/.local/share/nodenv/shims:/home/emiller/.local/share/nodenv/bin:/home/emiller/.local/share/android/bin:/home/emiller/.local/share/go/bin:/home/emiller/src/go/bin:/home/emiller/.anaconda3/bin:/home/emiller/.emacs.d/bin:/home/emiller/.local/bin:/home/emiller/.dotfiles/bin:/home/emiller/.local/share/dotfiles/shell.git.topic/bin:/home/emiller/.local/share/dotfiles/shell.sk.topic/bin:/home/emiller/.local/share/dotfiles/shell.tmux.topic/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/bin:/home/emiller/src/go/bin
