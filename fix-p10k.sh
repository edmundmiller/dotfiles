#!/bin/zsh
# Script to fix Powerlevel10k installation and custom segments

echo "=== Fixing Powerlevel10k Installation ==="
echo

# Step 1: Clean antidote cache
echo "Step 1: Cleaning antidote cache..."
rm -f ~/.config/zsh/cache/.zsh_plugins.zsh
rm -f ~/.config/zsh/cache/antidote_path
echo "✓ Cache cleaned"
echo

# Step 2: Try to manually clone Powerlevel10k if needed
echo "Step 2: Ensuring Powerlevel10k is available..."
P10K_DIR="$HOME/.local/share/zsh/plugins/romkatv/powerlevel10k"
if [[ ! -d "$P10K_DIR" ]]; then
    echo "Cloning Powerlevel10k..."
    mkdir -p "$(dirname "$P10K_DIR")"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
    echo "✓ Powerlevel10k directory exists"
fi
echo

# Step 3: Source the new configuration
echo "Step 3: Testing configuration..."
(
    source ~/.config/zsh/.zshrc
    if command -v p10k >/dev/null 2>&1; then
        echo "✓ p10k command is now available!"
    else
        echo "✗ p10k command still not available"
        echo "  Looking for Powerlevel10k installation..."
        find /nix/store -name "powerlevel10k.zsh-theme" 2>/dev/null | head -1
    fi
)
echo

# Step 4: Test custom functions
echo "Step 4: Testing custom segments..."
(
    source ~/.config/zsh/.p10k.zsh
    if type prompt_custom_vcs >/dev/null 2>&1; then
        echo "✓ Custom VCS function loaded"
    else
        echo "✗ Custom VCS function not loaded"
    fi
    if type prompt_todo >/dev/null 2>&1; then
        echo "✓ Todo function loaded"
    else
        echo "✗ Todo function not loaded"
    fi
)
echo

echo "=== Fix Complete ==="
echo
echo "Please:"
echo "1. Open a new terminal window"
echo "2. Navigate to ~/.config/dotfiles"
echo "3. You should now see the JJ segment in your prompt!"
echo
echo "If you still don't see it, run: source ~/.config/zsh/.zshrc"
echo "Then check if 'p10k' command is available: command -v p10k"