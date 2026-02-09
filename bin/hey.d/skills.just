import 'common.just'

# List all pinned agent skills and their versions
skills-list:
    #!/usr/bin/env bash
    set -euo pipefail
    SKILLS_FILE="{{ FLAKE_DIR }}/hosts/skills.nix"
    echo "Pinned agent skills:"
    echo ""
    # Extract names from the pinned block (between "pinned = {" and "END_PINNED_SKILLS")
    in_pinned=false
    while IFS= read -r line; do
        if [[ "$line" =~ "pinned = {" ]]; then
            in_pinned=true
            continue
        fi
        if [[ "$line" =~ "END_PINNED_SKILLS" ]]; then
            break
        fi
        if $in_pinned && [[ "$line" =~ ^[[:space:]]+([a-zA-Z0-9_-]+)[[:space:]]*=[[:space:]]*\{ ]]; then
            name="${BASH_REMATCH[1]}"
            block=$(awk "/^[[:space:]]*${name} = \{/,/\};/" "$SKILLS_FILE")
            owner=$(echo "$block" | grep 'owner' | sed 's/.*"\(.*\)".*/\1/')
            repo=$(echo "$block" | grep 'repo' | sed 's/.*"\(.*\)".*/\1/')
            rev=$(echo "$block" | grep 'rev' | sed 's/.*"\(.*\)".*/\1/')
            echo "  ${name}: ${owner}/${repo} @ ${rev:0:8}"
        fi
    done < "$SKILLS_FILE"
    if ! $in_pinned; then
        echo "  (no pinned skills)"
    fi

# Update a specific pinned skill to latest (or all if no arg)
skills-update name="":
    {{ FLAKE_DIR }}/bin/hey.d/skills-update.sh "{{ FLAKE_DIR }}/hosts/skills.nix" "{{ name }}"

# Add a new skill from GitHub (owner/repo or owner/repo@skill-name)
skills-add spec:
    {{ FLAKE_DIR }}/bin/hey.d/skills-add.sh "{{ FLAKE_DIR }}/hosts/skills.nix" "{{ spec }}"
