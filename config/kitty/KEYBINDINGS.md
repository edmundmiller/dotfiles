# Kitty Keybindings (Tmux-Style)

Prefix: `ctrl+c` (matches tmux, press twice to send SIGINT)

Based on [hlissner/dotfiles tmux.conf](https://github.com/hlissner/dotfiles/blob/master/config/tmux/tmux.conf)

## Quick Reference

### Window/Tab Management

All new tabs/windows inherit the current working directory.

| Binding                       | Action                   | Tmux Equivalent |
| ----------------------------- | ------------------------ | --------------- |
| `ctrl+c>c`                    | New tab (same cwd)       | `C-c c`         |
| `ctrl+c>shift+n`              | New OS window (same cwd) | -               |
| `ctrl+c>n` or `ctrl+c>ctrl+n` | Next tab                 | `C-c C-n`       |
| `ctrl+c>p` or `ctrl+c>ctrl+p` | Previous tab             | `C-c C-p`       |
| `ctrl+c>ctrl+w`               | Last tab                 | `C-c C-w`       |
| `ctrl+c>1-9`                  | Go to tab N              | `C-c 1-9`       |
| `ctrl+c>shift+w`              | Choose window            | `C-c W`         |
| `ctrl+c>.`                    | Choose window            | `C-c .`         |
| `ctrl+c>shift+x`              | Close tab                | `C-c X`         |

### Pane/Split Management

Splits inherit the current working directory.

| Binding          | Action                           | Tmux Equivalent |
| ---------------- | -------------------------------- | --------------- |
| `ctrl+c>v`       | Vertical split (stacked windows) | `C-c v`         |
| `ctrl+c>s`       | Horizontal split (side-by-side)  | `C-c s`         |
| `ctrl+c>h/j/k/l` | Navigate panes                   | `C-c h/j/k/l`   |
| `ctrl+c>x`       | Close pane                       | `C-c x`         |
| `ctrl+c>o`       | Zoom pane                        | `C-c o`         |
| `ctrl+c>-`       | Break pane to new tab            | `C-c -`         |

### Layout

| Binding          | Action        | Tmux Equivalent |
| ---------------- | ------------- | --------------- |
| `ctrl+c>shift+\` | Rotate layout | `C-c \|`        |
| `ctrl+c>=`       | Reset sizes   | `C-c =`         |

### Resize

| Binding        | Action   |
| -------------- | -------- |
| `ctrl+c>left`  | Narrower |
| `ctrl+c>right` | Wider    |
| `ctrl+c>up`    | Taller   |
| `ctrl+c>down`  | Shorter  |

### Session Management

| Binding               | Action          | Tmux Equivalent  |
| --------------------- | --------------- | ---------------- |
| `ctrl+c>shift+s`      | Browse sessions | `C-c S`          |
| `ctrl+c>/`            | Browse sessions | `C-c /`          |
| `ctrl+c>d`            | Default session | `C-c d` (detach) |
| `ctrl+c>m`            | Minimal session | -                |
| `ctrl+c>ctrl+shift+p` | Dev session     | -                |
| `ctrl+c>q`            | Close window    | `C-c q`          |

### Copy Mode & Misc

| Binding         | Action               | Tmux Equivalent |
| --------------- | -------------------- | --------------- |
| `ctrl+c>enter`  | Scrollback/copy mode | `C-c Enter`     |
| `ctrl+c>r`      | Reload config        | `C-c r`         |
| `ctrl+c>ctrl+r` | Clear/refresh        | `C-c C-r`       |

### Custom (Project Scripts)

| Binding          | Action           |
| ---------------- | ---------------- |
| `ctrl+c>shift+1` | Project script 1 |
| `ctrl+c>shift+2` | Project script 2 |
| `ctrl+c>shift+3` | Project script 3 |

## Philosophy

- Single letters for common ops (`c`, `v`, `s`, `h/j/k/l`)
- Capital/shift for destructive ops (`X` close, `S` session)
- Hold prefix (`ctrl+n/p/w`) for rapid switching
- Numbers for direct access

## Future Enhancements

- [ ] Vim-aware `C-h/j/k/l` navigation (no prefix)
- [ ] `ctrl+c>u/U` for jjui splits
- [ ] `ctrl+c>shift+c` for custom command prompt
