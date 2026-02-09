#!/usr/bin/env bash
set -euo pipefail

SKILLS_FILE="$1"
spec="$2"

# Parse spec: owner/repo or owner/repo@skill-name
if [[ "$spec" == *"@"* ]]; then
    repo_part="${spec%%@*}"
    skill_name="${spec##*@}"
else
    repo_part="$spec"
    skill_name=""
fi
owner="${repo_part%%/*}"
repo="${repo_part##*/}"

# Derive the nix attr name
if [ -n "$skill_name" ]; then
    nix_name="$skill_name"
else
    nix_name="$repo"
fi

echo "Adding skill: ${owner}/${repo}${skill_name:+@${skill_name}}"
echo "  Nix attr: ${nix_name}"

# Get latest commit
latest_rev=$(curl -sf "https://api.github.com/repos/${owner}/${repo}/commits/HEAD" | \
    python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])" 2>/dev/null)

if [ -z "$latest_rev" ]; then
    echo "  ✗ Could not fetch latest rev for ${owner}/${repo}"
    exit 1
fi
echo "  Rev: ${latest_rev:0:8}"

# Prefetch
raw_hash=$(nix-prefetch-url --unpack --type sha256 \
    "https://github.com/${owner}/${repo}/archive/${latest_rev}.tar.gz" 2>/dev/null)
sri_hash=$(nix hash to-sri --type sha256 "$raw_hash")
echo "  Hash: ${sri_hash}"

# Show SKILL.md for review
skill_subpath=""
[ -n "$skill_name" ] && skill_subpath="/${skill_name}"
echo ""
echo "  === SKILL.md preview ==="
curl -sf "https://raw.githubusercontent.com/${owner}/${repo}/${latest_rev}${skill_subpath}/SKILL.md" 2>/dev/null || {
    echo "  ✗ No SKILL.md found at ${owner}/${repo}${skill_subpath}"
    exit 1
}
echo ""
echo "  === end preview ==="
echo ""

read -rp "  Add this skill? [y/N] " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "  ⊘ Cancelled"
    exit 0
fi

# Check for existing entry
if grep -q "${nix_name} = {" "$SKILLS_FILE" 2>/dev/null; then
    echo "  ✗ Skill '${nix_name}' already exists. Use 'hey skills-update ${nix_name}' instead."
    exit 1
fi

# Build the nix entry and insert before END_PINNED_SKILLS marker
tmpfile=$(mktemp)

skill_attr=""
[ -n "$skill_name" ] && skill_attr="      skill = \"${skill_name}\";"

awk -v name="$nix_name" -v owner="$owner" -v repo="$repo" \
    -v rev="$latest_rev" -v hash="$sri_hash" -v skill_attr="$skill_attr" '
/# END_PINNED_SKILLS/ {
    print "    " name " = {"
    print "      owner = \"" owner "\";"
    print "      repo = \"" repo "\";"
    print "      rev = \"" rev "\";"
    print "      hash = \"" hash "\";"
    if (skill_attr != "") print skill_attr
    print "    };"
}
{ print }
' "$SKILLS_FILE" > "$tmpfile"

mv "$tmpfile" "$SKILLS_FILE"

echo "  ✓ Added ${nix_name} to skills.nix"
echo "  Run 'hey rebuild' to install"
