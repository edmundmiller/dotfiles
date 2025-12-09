#!/usr/bin/env bash
# Utility functions for formatting jj log output
#
# These functions provide consistent template formatting for commit display
# across all commands, ensuring a single source of truth for output formatting.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/../hooks/jj-templates.sh"
#   COMMIT=$(format_commit_short)
#   LIST=$(format_commit_list '@|@-')

set -euo pipefail

# Format a single commit with short ID and description
#
# Args:
#   $1 - revision (default: @)
#
# Returns: "abc123: commit description"
#
# Example:
#   CURRENT=$(format_commit_short)
#   PARENT=$(format_commit_short '@-')
#   echo "$CURRENT"  # Output: abc123: feat: add feature
format_commit_short() {
    local rev="${1:-@}"
    jj log -r "$rev" --no-graph -T 'concat(change_id.short(), ": ", description)' 2>/dev/null
}

# Format multiple commits as a list
#
# Args:
#   $1 - revision set (default: ancestors(@, 5))
#
# Returns: multi-line list of commits
#
# Example:
#   LIST=$(format_commit_list '@|@-')
#   echo "$LIST"
#   # Output:
#   # abc123: feat: add feature
#   # def456: fix: bug fix
format_commit_list() {
    local revset="${1:-ancestors(@, 5)}"
    jj log -r "$revset" -T 'concat(change_id.short(), ": ", description)' 2>/dev/null
}

# Format commit ancestors (parent chain)
#
# Args:
#   $1 - number of ancestors (default: 5)
#
# Returns: multi-line list of ancestor commits
#
# Example:
#   ANCESTORS=$(format_ancestors 3)
#   echo "$ANCESTORS"
format_ancestors() {
    local count="${1:-5}"
    jj log -r "ancestors(@, $count)" -T 'concat(change_id.short(), ": ", description)' 2>/dev/null
}
