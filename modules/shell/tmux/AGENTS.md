# Tmux Module - Agent Guide

## Purpose

Nix module for tmux terminal multiplexer with custom wrapper script for XDG path support, plugin management via nix, and Catppuccin theme integration.

## Module Structure

```
modules/shell/tmux/
├── default.nix     # Module definition
├── README.md       # Human docs
└── AGENTS.md       # This file

config/tmux/
├── config          # Main tmux config (keybindings, behavior)
├── theme.conf      # Catppuccin theme + auto-hide status bar
├── aliases.zsh     # Shell aliases (ta, tl, tf, etc.)
└── swap-pane.sh    # Pane swapping script for H/J/K/L bindings
```

## Key Technical Facts

- **Custom wrapper script**: Exports `TMUX_HOME`, `DOTFILES`, `DOTFILES_BIN` with fallback defaults for Ghostty compatibility (launches with `--noprofile --norc`)
- **XDG workaround**: tmux 3.0/3.1 doesn't support XDG natively; wrapper forces `-f "$TMUX_HOME/config"`
- **Plugin fetching**: `tmux-opencode-status` fetched via `fetchFromGitHub`, others from nixpkgs `tmuxPlugins.*`
- **Loading order**: Theme config MUST load BEFORE prefix-highlight plugin (sets `#{prefix_highlight}` placeholder for replacement)
- **Auto-generated extraInit**: Contains plugin `run-shell` commands and tmux-window-name configuration

## Dependencies

**Nix packages:**
- `pkgs.tmux` - Base tmux package
- `pkgs.tmuxPlugins.{copycat,prefix-highlight,yank}` - Standard plugins
- `pkgs.my.tmux-window-name` - Custom package (defined in `packages/`)

**Other modules:**
- `modules.shell.zsh` - Shell integration (tmuxifier init, aliases)
- `modules.theme` - Registers theme reload hook

## Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Env vars not set | Ghostty `--noprofile --norc` | Wrapper provides fallbacks |
| Plugin order wrong | prefix-highlight before theme | Check `rcFiles` loads first |
| tmuxifier not found | PATH not updated | Restart shell after rebuild |

## Related Files

- `modules/shell/zsh.nix` - Provides rcFiles/rcInit mechanism
- `modules/theme/default.nix` - Registers theme reload hooks
- `packages/tmux-window-name.nix` - Custom package definition
- `config/tmux/*` - Actual configuration files
