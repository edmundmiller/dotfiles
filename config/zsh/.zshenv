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
# This ensures /opt/homebrew/bin is in PATH for Emacs and non-login shells
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"

# Set up terminfo for NixOS (needed for TUI apps like opencode)
if [[ -d /run/current-system/sw/share/terminfo ]]; then
  export TERMINFO_DIRS="/run/current-system/sw/share/terminfo${TERMINFO_DIRS:+:$TERMINFO_DIRS}"
  # Set default TERM if empty (prevents TUI crashes in non-interactive SSH)
  [[ -z "$TERM" ]] && export TERM=xterm-256color
fi

# Add ~/.local/bin to PATH if it exists
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"

# Add dotfiles bin directory to PATH
[[ -d "$XDG_CONFIG_HOME/dotfiles/bin" ]] && export PATH="$XDG_CONFIG_HOME/dotfiles/bin:$PATH"

# Source nix-darwin generated environment (envFiles from modules)
[[ -f "$ZDOTDIR/extra.zshenv" ]] && source "$ZDOTDIR/extra.zshenv"