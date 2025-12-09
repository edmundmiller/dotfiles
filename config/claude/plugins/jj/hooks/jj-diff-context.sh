#!/usr/bin/env bash
# Utility functions for jj diff operations and analysis
#
# These functions provide a clean API for retrieving and formatting
# diff information for AI consumption and command execution.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/../hooks/jj-diff-context.sh"
#   SUMMARY=$(get_diff_summary)
#   STATS=$(get_diff_stats)

set -euo pipefail

# Get diff summary showing changed files
#
# Args:
#   $1 - revision (default: @)
#
# Returns: jj diff --summary output
#
# Example:
#   SUMMARY=$(get_diff_summary)
#   PARENT_SUMMARY=$(get_diff_summary '@-')
get_diff_summary() {
    local rev="${1:-@}"
    jj diff -r "$rev" --summary 2>/dev/null
}

# Get diff statistics showing line changes
#
# Args:
#   $1 - revision (default: @)
#
# Returns: jj diff --stat output
#
# Example:
#   STATS=$(get_diff_stats)
#   echo "$STATS"
get_diff_stats() {
    local rev="${1:-@}"
    jj diff -r "$rev" --stat 2>/dev/null
}

# Extract list of changed files from diff
#
# Args:
#   $1 - revision (default: @)
#
# Returns: newline-separated list of changed file paths
#
# Example:
#   FILES=$(extract_changed_files)
#   echo "$FILES" | while read -r file; do
#       echo "Changed: $file"
#   done
extract_changed_files() {
    local rev="${1:-@}"
    jj diff -r "$rev" --summary 2>/dev/null | grep -E '^[MADR] ' | awk '{print $2}'
}

# Format diff for AI consumption (TOON format preparation)
#
# Args:
#   $1 - revision (default: @)
#
# Returns: formatted diff context suitable for AI prompts
#
# Example:
#   AI_CONTEXT=$(format_diff_for_ai)
#   echo "$AI_CONTEXT" | claude-cli
format_diff_for_ai() {
    local rev="${1:-@}"

    # Header
    echo "## Diff Summary"
    echo ""
    get_diff_summary "$rev"
    echo ""

    # Statistics
    echo "## Diff Statistics"
    echo ""
    get_diff_stats "$rev"
}
