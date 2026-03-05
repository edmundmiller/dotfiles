#!/usr/bin/env zsh

# Ensure sudo respects our editor
export SUDO_EDITOR="$EDITOR"

# Global pi memory repo (pi-context-repo extension)
export PI_MEMORY_DIR="$HOME/.config/dotfiles/.pi/memory"

# bat theme — ansi delegates to terminal colors (works with dark/light mode switching)
export BAT_THEME=ansi
