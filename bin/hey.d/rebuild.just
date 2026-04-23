# System rebuild commands

import 'common.just'
import 'opencode.just'

DARWIN_REBUILD := "/run/current-system/sw/bin/darwin-rebuild"

# Rebuild the system (default: switch)
rebuild *args='switch': _check-flake-lock opencode-update
    #!/usr/bin/env bash
    set -euo pipefail

    if [[ "{{is_darwin}}" == "true" ]]; then
        if [[ -x "{{DARWIN_REBUILD}}" ]]; then
            sudo {{DARWIN_REBUILD}} --flake "{{FLAKE_DIR}}#{{flake_host}}" {{args}}
        else
            echo "darwin-rebuild not found at {{DARWIN_REBUILD}}, building via nix..."
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
        if [[ -x "{{DARWIN_REBUILD}}" ]]; then
            sudo {{DARWIN_REBUILD}} --flake "{{FLAKE_DIR}}#{{flake_host}}" test {{args}}
        else
            echo "darwin-rebuild not found at {{DARWIN_REBUILD}}, building via nix..."
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
        sudo {{DARWIN_REBUILD}} --rollback
    else
        nixos-rebuild --sudo --rollback
    fi

# Fail fast if tracked config files have unresolved merge conflicts
[private]
_check-flake-lock:
    #!/usr/bin/env bash
    set -euo pipefail

    # Check flake.lock
    lock="{{FLAKE_DIR}}/flake.lock"
    if grep -qE '^<{7}|^={7}|^>{7}' "$lock"; then
        echo "error: flake.lock contains git conflict markers — resolve them first" >&2
        grep -nE '^<{7}|^={7}|^>{7}' "$lock" >&2
        exit 1
    fi
    if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$lock" 2>/dev/null; then
        echo "error: flake.lock is not valid JSON — check for corruption or conflict markers" >&2
        exit 1
    fi

    # Check tracked source config files for conflict markers
    bad=0
    while IFS= read -r f; do
        if grep -qE '^<{7}|^={7}|^>{7}' "$f" 2>/dev/null; then
            echo "error: $f contains git conflict markers — resolve them first" >&2
            grep -nE '^<{7}|^={7}|^>{7}' "$f" >&2
            bad=1
        fi
    done < <(git -C "{{FLAKE_DIR}}" ls-files -- '*.nix' '*.json' '*.jsonc' '*.yml' '*.yaml' '*.toml')
    if (( bad )); then
        exit 1
    fi
