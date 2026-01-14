# Tmux Module

Terminal multiplexer with custom XDG path support, plugin management, and Catppuccin theme.

## Installation

Enable in host config:

```nix
modules.shell.tmux.enable = true;
```

## What This Module Provides

- **Custom wrapper script:** XDG path support + env var fallbacks for Ghostty
- **Plugin integration:** copycat, prefix-highlight, yank, opencode-status, window-name
- **Theme configuration:** Catppuccin with auto-hide status bar
- **Shell integration:** tmuxifier initialization, aliases

## Files

| Source | Destination | Purpose |
|--------|-------------|---------|
| `config/tmux/*` | `~/.config/tmux/` | Config, theme, scripts |
| (auto-generated) | `~/.config/tmux/extraInit` | Plugin loading, window-name config |

## Configuration Options

```nix
modules.shell.tmux = {
  enable = true;
  rcFiles = [ "${configDir}/tmux/theme.conf" ];  # Additional config files
};
```

Theme config loads BEFORE plugins (required for prefix-highlight placeholder replacement).

## Plugins

| Plugin | Description |
|--------|-------------|
| **copycat** | Enhanced search (regex, files, URLs, git hashes) |
| **prefix-highlight** | Visual prefix key indicator in status bar |
| **yank** | System clipboard integration |
| **opencode-status** | AI agent activity: ○ idle, ● busy, ◉ waiting, ✗ error, ✔ finished |
| **window-name** | Smart automatic window naming |

## tmux-window-name Customizations

Custom icon mappings for common programs:

| Icon | Programs |
|------|----------|
| `OC` | opencode |
| `CC` | claude |
| `V` | vim, nvim, vi |
| `G` | git |
| `JJ` | jjui |
| `λ` | zsh, bash, sh, fish |

Settings:
- Uses `~` for home directory abbreviation
- Max window name length: 24 chars
- Shows directory for: nvim, vim, git, jjui, opencode, claude
- Auto-detects node-based AI agents (opencode, claude)

## Notable Keybindings

| Key | Action |
|-----|--------|
| `C-c` | Prefix (not `C-b`) |
| `v` | Split horizontal |
| `s` | Split vertical |
| `h/j/k/l` | Pane navigation |
| `H/J/K/L` | Swap panes |
| `u` / `U` | Launch jjui (vertical/horizontal) |
| `r` | Reload config |
| `o` | Zoom pane |

See `config/tmux/config` for full keybinding reference.

## Aliases

| Alias | Command | Description |
|-------|---------|-------------|
| `ta` | `tmux attach` | Attach to session |
| `tl` | `tmux ls` | List sessions |
| `tf` | `tmux find-window` | Find window (inside tmux) |
| `mine` | `tmux detach -a` | Detach other clients |
| `tn` | (function) | Create new session |
| `tt` | (function) | Send command to next window |
| `tdup` | (function) | Start grouped session |

## Theme Features

- **Catppuccin** color scheme
- **Auto-hide status bar:** Status bar hides when only one window exists
- **Prefix highlight:** Visual feedback when prefix key is pressed

## Troubleshooting

### Environment variables not set (Ghostty)

Ghostty launches with `--noprofile --norc`, bypassing shell initialization. The wrapper script provides fallback defaults for `TMUX_HOME`, `DOTFILES`, and `DOTFILES_BIN`.

### tmuxifier not in PATH

Restart shell after `hey rebuild` to pick up `$TMUXIFIER/bin` in PATH.

### Plugins not loading

Check that `extraInit` exists and is sourced:
```bash
cat ~/.config/tmux/extraInit
```

Theme must load before prefix-highlight plugin. Verify `rcFiles` order in module config.
