#!/usr/bin/env zsh
# Set up XDG directories
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Set up zsh directories
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export ZSH_CACHE="$XDG_CACHE_HOME/zsh"

# Set up Homebrew environment (needed for all shells, including doom env)
# Cache brew shellenv output (~80ms savings) since it's stable
_brew_cache="$XDG_CACHE_HOME/zsh/brew_shellenv.zsh"
if [[ -x /opt/homebrew/bin/brew ]]; then
  if [[ ! -f "$_brew_cache" ]]; then
    mkdir -p "${_brew_cache:h}"
    /opt/homebrew/bin/brew shellenv > "$_brew_cache" 2>/dev/null
  fi
  source "$_brew_cache"
fi
unset _brew_cache

# Set up terminfo early (before nix-darwin extra.zshenv is sourced).
# Use full Nix search paths so TERM=ghostty resolves correctly on macOS too.
export TERMINFO_DIRS="$HOME/.nix-profile/share/terminfo:/etc/profiles/per-user/$USER/share/terminfo:/run/current-system/sw/share/terminfo:/nix/var/nix/profiles/default/share/terminfo:/usr/share/terminfo${TERMINFO_DIRS:+:$TERMINFO_DIRS}"
# Set default TERM if empty (prevents TUI crashes in non-interactive SSH)
[[ -z "$TERM" ]] && export TERM=xterm-256color

# Add ~/.local/bin to PATH if it exists
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"

# Add dotfiles bin directory to PATH
[[ -d "$XDG_CONFIG_HOME/dotfiles/bin" ]] && export PATH="$XDG_CONFIG_HOME/dotfiles/bin:$PATH"

# Source nix-darwin generated environment (envFiles from modules)
[[ -f "$ZDOTDIR/extra.zshenv" ]] && source "$ZDOTDIR/extra.zshenv"

# nix-homebrew exposes both ARM (/opt/homebrew) and Rosetta (/usr/local) brew entrypoints.
# In native ARM shells, macOS/path_helper can still leave /usr/local ahead of /opt/homebrew,
# which makes plain `brew` resolve to the Intel prefix and fail cask installs.
# Keep the native ARM brew first unless this shell is running under Rosetta.
typeset -U path PATH
if [[ "$(uname -m)" == "arm64" ]] && [[ "$(sysctl -in sysctl.proc_translated 2>/dev/null || echo 0)" != "1" ]]; then
  path=(
    /opt/homebrew/bin
    /opt/homebrew/sbin
    $path
  )
fi
