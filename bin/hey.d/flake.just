# Flake management commands

import 'common.just'

# Update flake inputs (all if none specified)
update *inputs:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{FLAKE_DIR}}"
    
    if [[ $# -eq 0 ]]; then
        echo "Updating all flake inputs..."
        nix flake update
    else
        echo "Updating flake inputs: $*"
        for input in "$@"; do
            nix flake lock --update-input "$input"
        done
    fi

# Alias for update
u *inputs: (update inputs)

# Update inputs and rebuild system
upgrade:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{FLAKE_DIR}}"
    echo "Updating flake inputs..."
    nix flake update
    echo "Rebuilding system..."
    
    if [[ "{{is_darwin}}" == "true" ]]; then
        if command -v darwin-rebuild >/dev/null 2>&1; then
            sudo darwin-rebuild --flake "{{FLAKE_DIR}}#{{flake_host}}" switch
        else
            echo "darwin-rebuild not found in PATH, building via nix..."
            nix build ".#darwinConfigurations.{{flake_host}}.system"
            if [[ -f ./result/sw/bin/darwin-rebuild ]]; then
                sudo ./result/sw/bin/darwin-rebuild --flake ".#{{flake_host}}" switch
            else
                echo "Error: darwin-rebuild not found in build result"
                exit 1
            fi
        fi
    else
        sudo nixos-rebuild --flake "{{FLAKE_DIR}}" switch
    fi

# Run flake checks
check:
    #!/usr/bin/env bash
    cd "{{FLAKE_DIR}}"
    nix flake check

# Show flake outputs
show:
    #!/usr/bin/env bash
    cd "{{FLAKE_DIR}}"
    nix flake show