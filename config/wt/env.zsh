# Worktrunk shell integration
# Required for `wt switch` to change directories
#
# This evaluates the shell integration code provided by worktrunk,
# which wraps the wt command to enable directory changes.

if command -v wt >/dev/null 2>&1; then
  eval "$(wt config shell init zsh)"
fi
