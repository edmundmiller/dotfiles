# 1Password Automation for Bugwarrior

## Problem
Getting repeated 1Password prompts every time bugwarrior runs (every 30 minutes).

## Solutions

### Option 1: Touch ID Authentication (Recommended for Desktop)
Enable biometric unlock for 1Password CLI:

```bash
# Run the setup script
~/.config/dotfiles/bin/setup-1password-biometric

# This enables Touch ID for 1Password CLI
op account add --address my.1password.com --shorthand personal
```

### Option 2: Service Account Token (Best for Automation)
Create a service account for bugwarrior:

1. Go to 1Password.com → Developer → Service Accounts
2. Create a new service account named "bugwarrior"
3. Grant access to the vaults containing your tokens
4. Copy the service account token

Add to your shell config:
```bash
# ~/.config/fish/config.local.fish
set -x OP_SERVICE_ACCOUNT_TOKEN "ops_your_token_here"
```

Or add to launchd plist:
```xml
<key>EnvironmentVariables</key>
<dict>
    <key>OP_SERVICE_ACCOUNT_TOKEN</key>
    <string>ops_your_token_here</string>
</dict>
```

### Option 3: Connect Server (For Multiple Services)
Run a local 1Password Connect server:

```bash
# Install connect server
brew install --cask 1password/tap/1password-connect

# Configure and run
# This provides a local API that doesn't require authentication
```

### Option 4: Cache Credentials in Keychain
Store the actual tokens in macOS Keychain instead:

```bash
# Store GitHub token
security add-generic-password \
  -a "edmundmiller" \
  -s "bugwarrior-github-token" \
  -w "your-github-token"

# Update bugwarrior config
github.token = @oracle:eval:security find-generic-password -s "bugwarrior-github-token" -w
```

## Current Workaround
The `bugwarrior-pull-cached` script attempts to cache the session, but macOS security still prompts for each `op` subprocess call.

## Recommendation
For automated sync every 30 minutes, use **Option 2** (Service Account Token) as it:
- Never prompts for authentication
- Works headlessly
- Is designed for automation
- Has read-only access to specific vaults