#!/usr/bin/env zsh

export NPM_CONFIG_USERCONFIG=$XDG_CONFIG_HOME/npm/config
export NODE_REPL_HISTORY=$XDG_CACHE_HOME/node/repl_history

# Yarn
export PATH="$PATH:$(yarn global bin)"
