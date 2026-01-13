# Worktrunk Module - Agent Guide

## Purpose

Nix module for worktrunk (wt) shell integration. Enables `wt switch` to change directories.

## Module Structure

```
modules/shell/wt/
├── default.nix   # Module definition
├── README.md     # Human docs
└── AGENTS.md     # This file

config/wt/
├── config.toml   # User config (symlinked to ~/.config/worktrunk/)
├── env.zsh       # Shell integration (eval's wt wrapper)
└── aliases.zsh   # Command shortcuts
```

## Key Facts

- **Binary source:** Homebrew (`brew install max-sixty/worktrunk/wt`), not nixpkgs
- **Shell integration:** `eval "$(wt config shell init zsh)"` in `env.zsh`
- **Config location:** `~/.config/worktrunk/config.toml` (symlink)
- **Depends on:** `.zshenv` sourcing `extra.zshenv` for envFiles to work

## Common Issues

**"shell integration not installed"** → `.zshenv` must source `extra.zshenv`

**wt not found** → Homebrew package not installed

## Related Files

- `modules/shell/zsh.nix` - Parent zsh module (envFiles/rcFiles mechanism)
- `config/zsh/.zshenv` - Must source `$ZDOTDIR/extra.zshenv`
