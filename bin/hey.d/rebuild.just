# System rebuild commands

import 'opencode.just'

# Rebuild the system (default: switch)
rebuild *args='switch': _check-flake-lock (_system-rebuild args) _post-rebuild

# Alias for rebuild
re *args='switch': (rebuild args)

# Test build (build and activate but don't add to boot menu)
test *args: (_system-rebuild "test" args)

# Roll back to previous generation
rollback:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "{{is_darwin}}" == "true" ]]; then
        sudo {{DARWIN_REBUILD}} --rollback
    else
        nixos-rebuild --sudo --rollback switch
    fi

# Legacy OpenClaw restart cascade (NixOS only)
[private]
_post-rebuild:
    #!/usr/bin/env bash
    set -euo pipefail
    [[ "{{is_darwin}}" == "true" ]] && exit 0
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

# Fail fast if tracked config files have unresolved merge conflicts
[private]
_check-flake-lock:
    #!/usr/bin/env bash
    set -euo pipefail

    lock="{{FLAKE_DIR}}/flake.lock"
    if grep -qE '^<{7}|^={7}|^>{7}' "$lock"; then
        echo "error: flake.lock contains git conflict markers — resolve them first" >&2
        grep -nE '^<{7}|^={7}|^>{7}' "$lock" >&2
        exit 1
    fi
    if ! jq empty "$lock" 2>/dev/null; then
        echo "error: flake.lock is not valid JSON — check for corruption or conflict markers" >&2
        exit 1
    fi

    # Single git grep instead of per-file loop
    if git -C "{{FLAKE_DIR}}" grep -nE '^<{7}|^={7}|^>{7}' -- '*.nix' '*.json' '*.jsonc' '*.yml' '*.yaml' '*.toml' 2>/dev/null; then
        echo "error: files above contain git conflict markers — resolve them first" >&2
        exit 1
    fi
