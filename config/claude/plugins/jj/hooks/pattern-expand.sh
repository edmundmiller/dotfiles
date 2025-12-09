#!/usr/bin/env bash
# Utility functions for pattern expansion in jj split operations
#
# These functions expand pattern keywords (test, docs, config) into
# appropriate glob patterns for jj move commands.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/../hooks/pattern-expand.sh"
#   PATTERNS=$(expand_pattern "test")
#   # Use in jj move: jj move --from @- $PATTERNS

set -euo pipefail

# Expand 'test' pattern to match test files
#
# Returns: space-separated list of -p 'glob:pattern' arguments
#
# Example:
#   PATTERNS=$(expand_test_pattern)
#   jj move --from @- $PATTERNS
expand_test_pattern() {
    echo "-p 'glob:**/*test*.py' -p 'glob:**/*test*.js' -p 'glob:**/*test*.ts' -p 'glob:**/*test*.jsx' -p 'glob:**/*test*.tsx' -p 'glob:**/*spec*.py' -p 'glob:**/*spec*.js' -p 'glob:**/*spec*.ts' -p 'glob:**/*spec*.jsx' -p 'glob:**/*spec*.tsx' -p 'glob:**/test_*.py' -p 'glob:**/*_test.go' -p 'glob:**/*Test.java' -p 'glob:**/*test*.java' -p 'glob:**/*test*.rs' -p 'glob:**/*test*.cpp' -p 'glob:**/*test*.c' -p 'glob:**/*test*.h'"
}

# Expand 'docs' pattern to match documentation files
#
# Returns: space-separated list of -p 'glob:pattern' arguments
#
# Example:
#   PATTERNS=$(expand_docs_pattern)
#   jj move --from @- $PATTERNS
expand_docs_pattern() {
    echo "-p 'glob:**.md' -p 'glob:**/README*' -p 'glob:**/CHANGELOG*' -p 'glob:**/LICENSE*' -p 'glob:docs/**/*'"
}

# Expand 'config' pattern to match configuration files
#
# Returns: space-separated list of -p 'glob:pattern' arguments
#
# Example:
#   PATTERNS=$(expand_config_pattern)
#   jj move --from @- $PATTERNS
expand_config_pattern() {
    echo "-p 'glob:**.json' -p 'glob:**.yaml' -p 'glob:**.yml' -p 'glob:**.toml' -p 'glob:**.ini' -p 'glob:**.conf' -p 'glob:**/.*rc' -p 'glob:**/.*ignore'"
}

# Expand custom pattern (user-provided glob)
#
# Args:
#   $1 - custom glob pattern
#
# Returns: -p 'glob:pattern' argument
#
# Example:
#   PATTERNS=$(expand_custom_pattern "*.md")
#   jj move --from @- $PATTERNS
expand_custom_pattern() {
    local pattern="$1"
    echo "-p 'glob:$pattern'"
}

# Main pattern expansion function - routes to appropriate expander
#
# Args:
#   $1 - pattern keyword (test, docs, config) or custom glob
#
# Returns: space-separated list of -p 'glob:pattern' arguments
#
# Example:
#   PATTERNS=$(expand_pattern "test")
#   PATTERNS=$(expand_pattern "docs")
#   PATTERNS=$(expand_pattern "*.md")
#   jj move --from @- $PATTERNS
expand_pattern() {
    local pattern="$1"

    case "$pattern" in
        test)
            expand_test_pattern
            ;;
        docs)
            expand_docs_pattern
            ;;
        config)
            expand_config_pattern
            ;;
        *)
            expand_custom_pattern "$pattern"
            ;;
    esac
}
