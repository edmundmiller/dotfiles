# Tmux Module

Terminal multiplexer with custom XDG path support, plugin management, and Catppuccin theme.

## Installation

Enable in host config:

```nix
modules.shell.tmux.enable = true;
```

## What This Module Provides

- **Custom wrapper script:** XDG path support + env var fallbacks for Ghostty
- **Plugin integration:** copycat, prefix-highlight, yank, opencode-status, opencode-integrated
- **Theme configuration:** Catppuccin with auto-hide status bar
- **Shell integration:** tmuxifier initialization, aliases

## Files

| Source           | Destination                | Purpose                            |
| ---------------- | -------------------------- | ---------------------------------- |
| `config/tmux/*`  | `~/.config/tmux/`          | Config, theme, scripts             |
| (auto-generated) | `~/.config/tmux/extraInit` | Plugin loading, window-name config |

## Configuration Options

```nix
modules.shell.tmux = {
  enable = true;
  rcFiles = [ "${configDir}/tmux/theme.conf" ];  # Additional config files
};
```

Theme config loads BEFORE plugins (required for prefix-highlight placeholder replacement).

## Dev Layouts (tml)

The `sesh` module provides tmux dev layouts via shell functions:

```
┌──────────────────┬─────────┐
│                  │         │
│    AI tool       │ lazygit │
│    (70%)         │  (30%)  │
│                  │         │
├──────────────────┴─────────┤
│         shell (15%)        │
└────────────────────────────┘
```

| Command     | Layout                     |
| ----------- | -------------------------- |
| `tml <cmd>` | Any tool + lazygit + shell |
| `nic`       | pi + lazygit + shell       |
| `nicx`      | opencode + lazygit + shell |

Enable with `modules.shell.sesh.enable = true;`.

## Plugins

| Plugin                  | Description                                                        |
| ----------------------- | ------------------------------------------------------------------ |
| **copycat**             | Enhanced search (regex, files, URLs, git hashes)                   |
| **prefix-highlight**    | Visual prefix key indicator in status bar                          |
| **yank**                | System clipboard integration                                       |
| **opencode-status**     | AI agent activity: ○ idle, ● busy, ◉ waiting, ✗ error, ✔ finished |
| **opencode-integrated** | Smart naming + OpenCode status                                     |

## tmux-opencode-integrated Behavior

Custom icon mappings for common programs:

| Icon | Programs            |
| ---- | ------------------- |
| `OC` | opencode            |
| `CC` | claude              |
| `V`  | vim, nvim, vi       |
| `G`  | git                 |
| `JJ` | jjui                |
| `λ`  | zsh, bash, sh, fish |

Settings:

- Uses `~` for home directory abbreviation
- Max window name length: 24 chars
- Shows directory for: nvim, vim, git, jjui, opencode, claude
- Auto-detects node-based AI agents (opencode, claude)

## Keybindings

Prefix is **`C-c`** (Ctrl+c), not `C-b`.

### Windows & Sessions

| Key     | Action                      |
| ------- | --------------------------- |
| `c`     | New window                  |
| `X`     | Kill window                 |
| `x`     | Kill pane                   |
| `q`     | Kill session                |
| `Q`     | Kill server                 |
| `n/C-n` | Next window                 |
| `p/C-p` | Previous window             |
| `S`     | Choose session              |
| `W / .` | Choose window               |
| `/ `    | Choose session              |
| `t`     | Session picker (sesh + fzf) |

### Panes

| Key       | Action                   |
| --------- | ------------------------ |
| `v`       | Split horizontal         |
| `s`       | Split vertical           |
| `h/j/k/l` | Navigate panes           |
| `H/J/K/L` | Swap panes               |
| `M`       | Swap to master           |
| `o`       | Zoom pane                |
| `< / >`   | Resize left/right (10)   |
| `+ / -`   | Resize down/up (5)       |
| `=`       | Break pane to new window |
| `_`       | Join pane                |
| `C-w`     | Last pane                |

### Splits & Tools

| Key | Action                           |
| --- | -------------------------------- |
| `u` | Split vertical + jjui            |
| `U` | Split horizontal + jjui          |
| `C` | Prompt: run command in new split |
| `g` | Git TUI popup                    |
| `G` | Critique (diff review) popup     |
| `f` | File picker popup                |
| `F` | File picker (git root) popup     |
| `D` | Directory picker popup           |
| `z` | Zoxide picker popup              |
| `d` | Zoxide dir-only picker popup     |

### Copy Mode & Misc

| Key       | Action                      |
| --------- | --------------------------- |
| `Enter`   | Enter copy mode             |
| `b`       | List paste buffers          |
| `B`       | Choose paste buffer         |
| `P`       | Paste from system clipboard |
| `i`       | Beads capture popup         |
| `m`       | Task note capture popup     |
| `N / `` ` | Daily note popup            |
| `e`       | Beads explore (cwd) popup   |
| `E`       | Beads explore (home) popup  |
| `r`       | Reload config               |

### Vim-aware Navigation (no prefix)

| Key   | Action                                     |
| ----- | ------------------------------------------ |
| `C-h` | Left (passed to vim if in vim)             |
| `C-j` | Down (passed to vim/pi if in vim or agent) |
| `C-k` | Up (passed to vim if in vim)               |
| `C-l` | Right (passed to vim if in vim)            |
| `C-\` | Last pane (passed to vim if in vim)        |

## Aliases

| Alias  | Command            | Description                 |
| ------ | ------------------ | --------------------------- |
| `ta`   | `tmux attach`      | Attach to session           |
| `tl`   | `tmux ls`          | List sessions               |
| `tf`   | `tmux find-window` | Find window (inside tmux)   |
| `mine` | `tmux detach -a`   | Detach other clients        |
| `tn`   | (function)         | Create new session          |
| `tt`   | (function)         | Send command to next window |
| `tdup` | (function)         | Start grouped session       |

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
