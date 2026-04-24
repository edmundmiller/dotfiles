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

DARWIN_REBUILD := "/run/current-system/sw/bin/darwin-rebuild"

# Nix system triple (e.g. aarch64-darwin, x86_64-linux)
nix_system := `nix eval --raw --expr builtins.currentSystem 2>/dev/null || echo unknown`

# Shared darwin-rebuild / nixos-rebuild dispatch
[private]
_system-rebuild action *args:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "{{is_darwin}}" == "true" ]]; then
        if [[ -x "{{DARWIN_REBUILD}}" ]]; then
            sudo {{DARWIN_REBUILD}} --flake "{{FLAKE_DIR}}#{{flake_host}}" {{action}} {{args}}
        else
            echo "darwin-rebuild not found at {{DARWIN_REBUILD}}, building via nix..."
            cd "{{FLAKE_DIR}}"
            nix build ".#darwinConfigurations.{{flake_host}}.system"
            if [[ -f ./result/sw/bin/darwin-rebuild ]]; then
                sudo ./result/sw/bin/darwin-rebuild --flake ".#{{flake_host}}" {{action}} {{args}}
            else
                echo "Error: darwin-rebuild not found in build result"
                exit 1
            fi
        fi
    else
        nixos-rebuild --flake "{{FLAKE_DIR}}" --sudo {{action}} {{args}}
    fi