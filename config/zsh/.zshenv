typeset -gU cdpath fpath mailpath path
path=( $XDG_BIN_HOME $DOTFILES/bin $path )
fpath=( $ZDOTDIR/functions $XDG_BIN_HOME $fpath )

# envvars
export SHELL=$(command -v zsh)
export LANG=${LANG:-en_US.UTF-8}
export PAGER=less
export LESS='-R -i -w -M -z-4'
export LESSHISTFILE="$XDG_DATA_HOME/lesshst"
# FIXME breaks modules/shell/mail
# export PASSWORD_STORE_DIR="$XDG_DATA_HOME/password-store"

for file in $XDG_CONFIG_HOME/zsh/rc.d/env.*.zsh(N); do
  source $file
done

function _cache {
  local cache_dir="$XDG_CACHE_HOME/${SHELL##*/}"
  local cache="$cache_dir/$1"
  if [[ ! -f $cache || ! -s $cache ]]; then
    echo "Caching $1"
    mkdir -p $cache_dir
    "$@" >$cache
  fi
  source $cache
}
