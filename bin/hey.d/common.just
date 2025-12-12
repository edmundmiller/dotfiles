# Common variables for hey commands

# Get the dotfiles directory (one level up from bin)
FLAKE_DIR := justfile_directory() / ".."

# Cache hostname once to avoid multiple invocations
_hostname := `hostname -s`

# Get the correct flake configuration name based on hostname
# Use FLAKE_HOST env var if set, otherwise map known hostnames
flake_host := env_var_or_default('FLAKE_HOST', if _hostname == "Mac" {
    "MacTraitor-Pro"
} else if _hostname == "mactraitor-pro" {
    "MacTraitor-Pro"
} else if _hostname == "L19W56QXR4" {
    "Seqeratop"
} else {
    _hostname
})

# Check if we're on Darwin or NixOS
is_darwin := if `uname -s` == "Darwin" { "true" } else { "false" }