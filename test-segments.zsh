#!/bin/zsh
# Test script to debug why segments aren't showing

echo "=== Testing P10k Segments ==="
echo

# First, source the zshrc to get P10k loaded
echo "0. Loading shell configuration..."
source ~/.config/zsh/.zshrc 2>/dev/null
echo "   Configuration loaded"
echo

# Check if p10k is available
echo "1. P10k command status:"
if command -v p10k >/dev/null 2>&1; then
    echo "   ✓ p10k command available"
else
    echo "   ✗ p10k command NOT available"
    echo "   Attempting manual load..."
    if [[ -f "$HOME/.local/share/zsh/plugins/romkatv/powerlevel10k/powerlevel10k.zsh-theme" ]]; then
        source "$HOME/.local/share/zsh/plugins/romkatv/powerlevel10k/powerlevel10k.zsh-theme"
        echo "   Manually loaded P10k"
    fi
fi
echo

# Check if functions are defined
echo "2. Custom function status:"
if type prompt_custom_vcs >/dev/null 2>&1; then
    echo "   ✓ prompt_custom_vcs defined"
else
    echo "   ✗ prompt_custom_vcs NOT defined"
fi
if type prompt_todo >/dev/null 2>&1; then
    echo "   ✓ prompt_todo defined"
else
    echo "   ✗ prompt_todo NOT defined"
fi
echo

# Check current prompt elements
echo "3. Current prompt configuration:"
echo "   Left elements: ${POWERLEVEL9K_LEFT_PROMPT_ELEMENTS[@]}"
echo "   Right elements: ${POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS[@]}"
echo

# Check if we're in a jj repo
echo "4. JJ repository status:"
if jj root >/dev/null 2>&1; then
    echo "   ✓ In JJ repository: $(jj root)"
    echo "   Current change: $(jj log -r @ --no-graph -T 'change_id.short(8)')"
else
    echo "   ✗ Not in JJ repository"
fi
echo

# Test calling the function manually
echo "5. Testing manual function call:"
echo "   Simulating P10k context..."

# Set up minimal P10k context variables
_p9k__prompt_side="left"
_p9k__segment_name="custom_vcs"

# Try to call the function
echo "   Calling prompt_custom_vcs..."
if prompt_custom_vcs 2>&1; then
    echo "   Function executed (may have failed due to context)"
else
    echo "   Function returned non-zero"
fi
echo

# Check if segments are registered with P10k
echo "6. Checking P10k segment registration:"
echo "   All defined functions starting with 'prompt_':"
typeset -f | grep "^prompt_" | head -10
echo

echo "7. Checking if P10k recognizes custom segments:"
# This will show if P10k knows about our segments
p10k display -a '*custom_vcs*' 2>&1 || echo "   custom_vcs segment not recognized by P10k"
p10k display -a '*todo*' 2>&1 || echo "   todo segment not recognized by P10k"
echo

echo "=== Debugging Complete ==="
echo
echo "If segments aren't showing, likely issues:"
echo "1. P10k doesn't recognize the custom segments"
echo "2. Segments aren't in POWERLEVEL9K_LEFT/RIGHT_PROMPT_ELEMENTS"
echo "3. Functions aren't loaded when P10k initializes"