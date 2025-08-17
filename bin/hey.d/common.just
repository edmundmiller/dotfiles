# Common variables for hey commands

# Get the dotfiles directory (one level up from bin)
FLAKE_DIR := justfile_directory() / ".."

# Get the correct flake configuration name based on hostname
flake_host := if `hostname -s` == "Mac" { "MacTraitor-Pro" } else { `hostname -s` }

# Check if we're on Darwin or NixOS
is_darwin := if `uname` == "Darwin" { "true" } else { "false" }