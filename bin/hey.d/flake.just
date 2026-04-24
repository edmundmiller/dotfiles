# Flake management commands

# Update flake inputs (all if none specified)
update *inputs:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{FLAKE_DIR}}"

    if [[ -z "{{inputs}}" ]]; then
        echo "Updating all flake inputs..."
        nix flake update
    else
        echo "Updating flake inputs: {{inputs}}"
        for input in {{inputs}}; do
            nix flake update "$input"
        done
    fi

# Alias for update
u *inputs: (update inputs)

# Update inputs and rebuild system
upgrade: update (rebuild)

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
        CHILD_INPUTS=$(jq -r '.nodes.root.inputs | keys[]' skills/flake.lock | sort)
        PARENT_CHILD_INPUTS=$(jq -r '.nodes["skills-catalog"].inputs | keys[]' flake.lock | sort)
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
        if nix build ".#checks.{{nix_system}}.treefmt" --no-link 2>&1; then
            echo "✓ Formatting OK"
        else
            echo "✗ Formatting check FAILED (run 'nix fmt' to fix)"
            FAILED=1
        fi

        # 3. Run pre-commit check
        echo ""
        echo "==> Running pre-commit hooks check..."
        if nix build ".#checks.{{nix_system}}.pre-commit" --no-link 2>&1; then
            echo "✓ Pre-commit hooks OK"
        else
            echo "✗ Pre-commit check FAILED"
            FAILED=1
        fi

        # 4. Run zunit tests
        echo ""
        echo "==> Running zunit shell tests..."
        if nix build ".#checks.{{nix_system}}.zunit-tests" --no-link 2>&1; then
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
