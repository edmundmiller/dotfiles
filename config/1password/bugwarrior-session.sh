#!/usr/bin/env bash
#
# 1Password session management for bugwarrior
# Source this file to set up 1Password authentication
#

# Option 1: Use 1Password CLI with biometric unlock (recommended)
# This requires setting up Touch ID for 1Password CLI:
# op account add --address my.1password.com --email your@email.com

# Option 2: Use service account token (for headless operation)
# export OP_SERVICE_ACCOUNT_TOKEN="your-service-account-token"

# Option 3: Use long-lived session with cached credentials
if [ -z "$OP_SESSION_my" ]; then
    # Try to use biometric authentication first
    if op account list --account my.1password.com &>/dev/null; then
        # Already signed in
        export OP_BIOMETRIC_UNLOCK_ENABLED=true
    else
        # Sign in with biometric if available
        eval $(op signin --account my.1password.com)
    fi
fi

# Cache directory for tokens
export OP_CACHE_DIR="${HOME}/.cache/1password"
mkdir -p "$OP_CACHE_DIR"