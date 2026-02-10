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

# Run flake checks (platform-aware)
check:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{FLAKE_DIR}}"
    
    if [[ "{{is_darwin}}" == "true" ]]; then
        echo "Running Darwin-compatible checks (skipping NixOS configs)..."
        FAILED=0
        
        # 0. Check child flake locks are synced with parent
        echo ""
        echo "==> Checking child flake lock sync..."
        CHILD_INPUTS=$(nix flake metadata ./skills --json 2>/dev/null | jq -r '.locks.nodes.root.inputs | keys[]' | sort)
        PARENT_CHILD_INPUTS=$(nix flake metadata . --json 2>/dev/null | jq -r '.locks.nodes["skills-catalog"].inputs | keys[]' | sort)
        if [[ "$CHILD_INPUTS" == "$PARENT_CHILD_INPUTS" ]]; then
            echo "✓ Child flake locks synced"
        else
            echo "✗ skills/flake.lock is out of sync with parent flake.lock!"
            echo "  Child inputs:  $CHILD_INPUTS"
            echo "  Parent inputs: $PARENT_CHILD_INPUTS"
            echo "  Fix: nix flake update skills-catalog"
            FAILED=1
        fi
        
        # 1. Check Darwin configuration evaluates correctly
        echo ""
        echo "==> Checking Darwin configuration: {{flake_host}}"
        if nix eval ".#darwinConfigurations.{{flake_host}}.system" --apply 'x: "OK"' 2>&1; then
            echo "✓ Darwin configuration OK"
        else
            echo "✗ Darwin configuration FAILED"
            FAILED=1
        fi
        
        # 2. Run treefmt check
        echo ""
        echo "==> Running treefmt formatting check..."
        if nix build ".#checks.aarch64-darwin.treefmt" --no-link 2>&1; then
            echo "✓ Formatting OK"
        else
            echo "✗ Formatting check FAILED (run 'nix fmt' to fix)"
            FAILED=1
        fi
        
        # 3. Run pre-commit check
        echo ""
        echo "==> Running pre-commit hooks check..."
        if nix build ".#checks.aarch64-darwin.pre-commit" --no-link 2>&1; then
            echo "✓ Pre-commit hooks OK"
        else
            echo "✗ Pre-commit check FAILED"
            FAILED=1
        fi
        
        # 4. Run zunit tests
        echo ""
        echo "==> Running zunit shell tests..."
        if nix build ".#checks.aarch64-darwin.zunit-tests" --no-link 2>&1; then
            echo "✓ Shell tests OK"
        else
            echo "✗ Shell tests FAILED"
            FAILED=1
        fi
        
        echo ""
        if [[ $FAILED -eq 0 ]]; then
            echo "✓ All Darwin checks passed!"
        else
            echo "✗ Some checks failed. For full checks including NixOS configs, run on Linux."
            exit 1
        fi
    else
        # On Linux, run full flake check
        echo "Running full flake check..."
        nix flake check
    fi

# Show flake outputs
show:
    #!/usr/bin/env bash
    cd "{{FLAKE_DIR}}"
    nix flake show