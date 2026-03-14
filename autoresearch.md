# Autoresearch: minimal nvim config

## Objective

Build a clean, minimal, pleasant Neovim setup in `config/nvim/` with strong defaults and essential productivity features.

## Metrics

- **Primary**: `startup_ms` (ms, lower is better)
- **Secondary**: `plugin_count` (lower), `config_boot_ok` (must be 1)

## How to Run

`./autoresearch.sh` — prints `METRIC name=value` lines.

## Files in Scope

- `config/nvim/init.lua`
- `config/nvim/lua/options.lua`
- `config/nvim/lua/keymaps.lua`
- `config/nvim/lua/lazy-plugins.lua`
- `config/nvim/lua/kickstart/plugins/*.lua`
- `config/nvim/lua/custom/plugins/*.lua`
- `config/nvim/lazy-lock.json`

## Off Limits

- Files outside `config/nvim/` except `autoresearch.*` harness files.

## Constraints

- Must boot cleanly in headless mode.
- Keep UX nice: theme, fuzzy finder, git signs, treesitter, LSP, completion.
- Prefer less code/plugins over more.
- Non-interactive only.

## What's Been Tried

- Restarted session for this target (older autoresearch artifacts were for a different Pi setup task).
