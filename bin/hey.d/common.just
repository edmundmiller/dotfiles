# Common variables for hey commands

# Get the dotfiles directory (one level up from bin)
FLAKE_DIR := justfile_directory() / ".."

# Get the correct flake configuration name based on hostname
# Use FLAKE_HOST env var if set, otherwise map known hostnames
flake_host := env_var_or_default('FLAKE_HOST', if `hostname -s` == "Mac" {
    "MacTraitor-Pro"
} else if `hostname -s` == "L19W56QXR4" {
    "Seqeratop"
} else {
    `hostname -s`
})

# Check if we're on Darwin or NixOS
is_darwin := if `uname` == "Darwin" { "true" } else { "false" }