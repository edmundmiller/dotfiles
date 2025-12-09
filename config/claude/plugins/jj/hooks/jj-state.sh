#!/usr/bin/env bash
# Utility functions for inspecting jj commit state
#
# These functions provide a clean API for checking commit state
# without duplicating jj template logic across commands.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/../hooks/jj-state.sh"
#   STATE=$(get_commit_state)
#   EMPTINESS=$(is_empty_commit)

set -euo pipefail

# Check if current commit has a description
#
# Returns: "has" or "none"
#
# Example:
#   HAS_DESC=$(get_commit_state)
#   if [[ "$HAS_DESC" == "has" ]]; then
#       echo "Commit already has description"
#   fi
get_commit_state() {
    jj log -r @ --no-graph -T 'if(description, "has", "none")' 2>/dev/null
}

# Check if current commit is empty (has no changes)
#
# Returns: "empty" or "has_changes"
#
# Example:
#   IS_EMPTY=$(is_empty_commit)
#   if [[ "$IS_EMPTY" == "empty" ]]; then
#       echo "Commit has no changes yet"
#   fi
is_empty_commit() {
    jj log -r @ --no-graph -T 'if(empty, "empty", "has_changes")' 2>/dev/null
}

# Get formatted working copy status
#
# Returns: jj status output
#
# Example:
#   STATUS=$(get_working_copy_status)
#   echo "$STATUS"
get_working_copy_status() {
    jj status
}
