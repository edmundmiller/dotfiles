#!/bin/zsh
# Debug script for P10k configuration issues

echo "=== P10k Configuration Debug ==="
echo "Date: $(date)"
echo "PWD: $PWD"
echo "ZSH_VERSION: $ZSH_VERSION"
echo "ZDOTDIR: $ZDOTDIR"
echo

echo "=== Checking P10k Installation ==="
if command -v p10k >/dev/null 2>&1; then
    echo "✓ p10k command available"
else
    echo "✗ p10k command NOT available"
fi

echo

echo "=== Checking Config File ==="
CONFIG_FILE="/Users/emiller/.config/dotfiles/config/zsh/.p10k.zsh"
if [[ -f "$CONFIG_FILE" ]]; then
    echo "✓ Config file exists: $CONFIG_FILE"
    echo "File size: $(wc -c < "$CONFIG_FILE") bytes"
    echo "Last modified: $(stat -f "%Sm" "$CONFIG_FILE")"
else
    echo "✗ Config file missing: $CONFIG_FILE"
fi

echo

echo "=== Checking Symlink ==="
SYMLINK_FILE="$ZDOTDIR/.p10k.zsh"
if [[ -L "$SYMLINK_FILE" ]]; then
    echo "✓ Symlink exists: $SYMLINK_FILE"
    echo "Points to: $(readlink "$SYMLINK_FILE")"
else
    echo "✗ Symlink missing: $SYMLINK_FILE"
fi

echo

echo "=== Testing Function Loading ==="
# Source the config in a subshell to test
if (source "$CONFIG_FILE" && type prompt_custom_vcs >/dev/null 2>&1); then
    echo "✓ Custom functions load successfully"
else
    echo "✗ Custom functions fail to load"
fi

echo

echo "=== Testing JJ Detection ==="
if command -v jj >/dev/null 2>&1; then
    echo "✓ jj command available"
    if jj root >/dev/null 2>&1; then
        echo "✓ Currently in a jj repository"
        echo "JJ root: $(jj root 2>/dev/null)"
        echo "Current change: $(jj log -r @ --no-graph -T 'change_id.short(8)' 2>/dev/null)"
    else
        echo "✗ Not in a jj repository"
    fi
else
    echo "✗ jj command NOT available"
fi

echo

echo "=== Current P10k Variables ==="
env | grep POWERLEVEL9K | head -5 || echo "No POWERLEVEL9K variables set"

echo

echo "=== Testing Manual Function Call ==="
# Test the function manually
echo "Attempting to load and call prompt_custom_vcs..."
(
    source "$CONFIG_FILE"
    if type prompt_custom_vcs >/dev/null 2>&1; then
        echo "Function loaded, testing call..."
        # This won't work outside p10k context, but we can test the logic
        prompt_custom_vcs 2>&1 || echo "Function call completed (expected to fail outside p10k context)"
    else
        echo "Function not loaded"
    fi
)

echo
echo "=== Debug Complete ==="
echo "Run this script in your terminal: zsh debug-p10k.sh"