# OpenCode commands

import 'common.just'

OPENCODE_CACHE := env_var('HOME') / ".cache/opencode"

# Update OpenCode plugins (clear cache for fresh @latest installs)
opencode-update:
    #!/usr/bin/env bash
    set -euo pipefail
    
    cache_dir="{{OPENCODE_CACHE}}"
    
    if [[ -d "$cache_dir/node_modules" ]] || [[ -f "$cache_dir/bun.lock" ]]; then
        echo "Clearing OpenCode plugin cache..."
        rm -rf "$cache_dir/node_modules" "$cache_dir/bun.lock" 2>/dev/null || true
    fi
