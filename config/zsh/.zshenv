typeset -gU cdpath fpath mailpath path
path=( $XDG_BIN_HOME $DOTFILES/bin $path )
fpath=( $ZDOTDIR/functions $XDG_BIN_HOME $fpath )

# envvars
export SHELL=$(command -v zsh)
export LANG=${LANG:-en_US.UTF-8}
export PAGER=less
export LESS='-R -i -w -M -z-4'
export LESSHISTFILE="$XDG_DATA_HOME/lesshst"
export PASSWORD_STORE_DIR="$XDG_DATA_HOME/password-store"
