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
        nixos-rebuild --flake "{{FLAKE_DIR}}" --sudo {{args}}

        # Legacy OpenClaw deployments used a user unit that needed a post-switch
        # try-restart. Hermes on the NUC runs as a system service and is restarted
        # by activation, so only touch the legacy user unit when it still exists.
        # Skip when we ARE openclaw (OPS-24).
        if systemctl list-unit-files hermes-agent.service >/dev/null 2>&1; then
            echo "=== hermes-agent: system-managed restart handled by activation ==="
        elif grep -q 'openclaw-gateway' /proc/self/cgroup 2>/dev/null; then
            echo "=== openclaw-gateway: skipping restart (deploy triggered by openclaw) ==="
        elif systemctl --user list-unit-files openclaw-gateway.service >/dev/null 2>&1; then
            echo "=== try-restart openclaw-gateway ==="
            systemctl --user try-restart openclaw-gateway.service
        else
            echo "=== no legacy openclaw-gateway user unit present ==="
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
        nixos-rebuild --flake "{{FLAKE_DIR}}" --sudo test {{args}}
    fi

# Roll back to previous generation
rollback:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "{{is_darwin}}" == "true" ]]; then
        sudo darwin-rebuild --rollback
    else
        nixos-rebuild --sudo --rollback
    fi