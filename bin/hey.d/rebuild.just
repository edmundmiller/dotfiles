# System rebuild commands

import 'common.just'
import 'opencode.just'

# Rebuild the system (default: switch)
rebuild *args='switch': opencode-update
    #!/usr/bin/env bash
    set -euo pipefail
    
    if [[ "{{is_darwin}}" == "true" ]]; then
        if command -v darwin-rebuild >/dev/null 2>&1; then
            sudo darwin-rebuild --flake "{{FLAKE_DIR}}#{{flake_host}}" {{args}}
        else
            echo "darwin-rebuild not found in PATH, building via nix..."
            cd "{{FLAKE_DIR}}"
            nix build ".#darwinConfigurations.{{flake_host}}.system"
            if [[ -f ./result/sw/bin/darwin-rebuild ]]; then
                sudo ./result/sw/bin/darwin-rebuild --flake ".#{{flake_host}}" {{args}}
            else
                echo "Error: darwin-rebuild not found in build result"
                exit 1
            fi
        fi
    else
        sudo nixos-rebuild --flake "{{FLAKE_DIR}}" {{args}}

        # openclaw-gateway uses X-RestartIfChanged=false to survive rebuilds.
        # Restart it explicitly — unless we ARE openclaw (OPS-24).
        if systemctl --user is-active openclaw-gateway.service &>/dev/null; then
            if grep -q 'openclaw-gateway' /proc/self/cgroup 2>/dev/null; then
                echo "=== openclaw-gateway: skipping restart (deploy triggered by openclaw) ==="
            else
                echo "=== Restarting openclaw-gateway ==="
                systemctl --user restart openclaw-gateway.service
            fi
        fi
    fi

# Alias for rebuild
re *args='switch': (rebuild args)

# Test build (build and activate but don't add to boot menu)
test *args:
    #!/usr/bin/env bash
    set -euo pipefail
    
    if [[ "{{is_darwin}}" == "true" ]]; then
        if command -v darwin-rebuild >/dev/null 2>&1; then
            sudo darwin-rebuild --flake "{{FLAKE_DIR}}#{{flake_host}}" test {{args}}
        else
            echo "darwin-rebuild not found in PATH, building via nix..."
            cd "{{FLAKE_DIR}}"
            nix build ".#darwinConfigurations.{{flake_host}}.system"
            if [[ -f ./result/sw/bin/darwin-rebuild ]]; then
                sudo ./result/sw/bin/darwin-rebuild --flake ".#{{flake_host}}" test {{args}}
            else
                echo "Error: darwin-rebuild not found in build result"
                exit 1
            fi
        fi
    else
        sudo nixos-rebuild --flake "{{FLAKE_DIR}}" test {{args}}
    fi

# Roll back to previous generation
rollback:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "{{is_darwin}}" == "true" ]]; then
        sudo darwin-rebuild --rollback
    else
        sudo nixos-rebuild --rollback
    fi