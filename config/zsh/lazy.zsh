#!/usr/bin/env zsh
# =============================================================================
# Lazy Loading Patterns for Slow Commands
# =============================================================================
# Based on: https://willhbr.net/2025/01/06/lazy-load-command-completions-for-a-faster-shell-startup/
#
# Commands that generate completions or run `eval $(cmd init)` at startup
# can add significant latency. This file documents the patterns used.
#
# Measured savings:
#   jj completions: ~50ms (config/jj/aliases.zsh)
#   fnm env:        ~30ms (modules/dev/node.nix)
#   sdkman init:    ~100ms (.zshrc)
#   bun completions: ~20ms (.zshrc)
#
# =============================================================================
# PATTERN 1: Completion lazy loading (preserves completion after first use)
# =============================================================================
#
#   function jj {
#     if [[ -z $_JJ_LOADED ]]; then
#       source <(command jj util completion zsh)
#       _JJ_LOADED=1
#     fi
#     command jj "$@"
#   }
#
# =============================================================================
# PATTERN 2: Full init lazy loading (for version managers like fnm, pyenv, sdk)
# =============================================================================
#
#   function sdk {
#     unfunction sdk java gradle kotlin  # Remove all related stubs
#     source "$SDKMAN_DIR/bin/sdkman-init.sh"
#     sdk "$@"
#   }
#   # Create stubs for related commands
#   for cmd in java gradle kotlin; do
#     eval "function $cmd { sdk; command $cmd \"\$@\"; }"
#   done
#
# =============================================================================
# When to use which pattern:
# - Pattern 1: Command has separate completion that's expensive but you want
#   to keep the wrapper function (e.g., jj with custom config flags)
# - Pattern 2: Full environment init needed (modifies PATH, sets vars), and
#   related commands should also trigger init
# =============================================================================
