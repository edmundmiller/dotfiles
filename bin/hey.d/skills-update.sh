#!/usr/bin/env bash
set -euo pipefail

SKILLS_FILE="$1"
filter_name="${2:-}"

update_skill() {
    local skill_name="$1"
    local owner repo current_rev

    # Extract skill metadata from nix file
    local block
    block=$(awk "/^[[:space:]]*${skill_name} = \{/,/\};/" "$SKILLS_FILE")
    owner=$(echo "$block" | grep 'owner' | sed 's/.*"\(.*\)".*/\1/')
    repo=$(echo "$block" | grep 'repo' | sed 's/.*"\(.*\)".*/\1/')
    current_rev=$(echo "$block" | grep 'rev' | sed 's/.*"\(.*\)".*/\1/')
    local skill_path
    skill_path=$(echo "$block" | grep 'skill' | sed 's/.*"\(.*\)".*/\1/' || true)

    if [ -z "$owner" ] || [ -z "$repo" ]; then
        echo "  ✗ Could not parse ${skill_name}"
        return 1
    fi

    # Get latest commit on default branch
    local latest_rev
    latest_rev=$(curl -sf "https://api.github.com/repos/${owner}/${repo}/commits/HEAD" | \
        python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])" 2>/dev/null)

    if [ -z "$latest_rev" ]; then
        echo "  ✗ Could not fetch latest rev for ${owner}/${repo}"
        return 1
    fi

    if [ "$current_rev" = "$latest_rev" ]; then
        echo "  ✓ ${skill_name}: already up to date (${current_rev:0:8})"
        return 0
    fi

    echo "  ↻ ${skill_name}: ${current_rev:0:8} → ${latest_rev:0:8}"

    # Prefetch to get the SRI hash
    local raw_hash new_hash
    raw_hash=$(nix-prefetch-url --unpack --type sha256 \
        "https://github.com/${owner}/${repo}/archive/${latest_rev}.tar.gz" 2>/dev/null)
    new_hash=$(nix hash to-sri --type sha256 "$raw_hash")

    if [ -z "$new_hash" ]; then
        echo "  ✗ Could not compute hash for ${skill_name}"
        return 1
    fi

    # Show diff of SKILL.md for review
    echo ""
    echo "  Changes to ${skill_name}/SKILL.md:"
    local skill_subpath=""
    [ -n "$skill_path" ] && skill_subpath="/${skill_path}"
    local old_url="https://raw.githubusercontent.com/${owner}/${repo}/${current_rev}${skill_subpath}/SKILL.md"
    local new_url="https://raw.githubusercontent.com/${owner}/${repo}/${latest_rev}${skill_subpath}/SKILL.md"
    diff --color=always <(curl -sf "$old_url" 2>/dev/null || echo "(new skill)") \
         <(curl -sf "$new_url" 2>/dev/null || echo "(not found)") || true
    echo ""

    # Prompt for confirmation
    read -rp "  Accept update for ${skill_name}? [y/N] " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "  ⊘ Skipped ${skill_name}"
        return 0
    fi

    # Update the nix file in-place
    sed -i '' "s|rev = \"${current_rev}\"|rev = \"${latest_rev}\"|" "$SKILLS_FILE"
    sed -i '' "/${skill_name}/,/hash =/{s|hash = \"[^\"]*\"|hash = \"${new_hash}\"|;}" "$SKILLS_FILE"

    echo "  ✓ Updated ${skill_name} — rebuild to apply"
}

if [ -n "$filter_name" ]; then
    update_skill "$filter_name"
else
    echo "Checking all pinned skills for updates..."
    echo ""
    grep -E '^\s+\w.* = \{' "$SKILLS_FILE" | while read -r line; do
        skill_name=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -d' ' -f1)
        update_skill "$skill_name"
    done
fi
