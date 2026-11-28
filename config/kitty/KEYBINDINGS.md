# Kitty prefix keybindings

Prefix: `ctrl+c` (press twice to send SIGINT)

## Quick Reference

### Window/Tab Management

All new tabs/windows inherit the current working directory.

| Binding                       | Action                   |
| ----------------------------- | ------------------------ |
| `ctrl+c>c`                    | New tab (same cwd)       |
| `ctrl+c>shift+n`              | New OS window (same cwd) |
| `ctrl+c>n` or `ctrl+c>ctrl+n` | Next tab                 |
| `ctrl+c>p` or `ctrl+c>ctrl+p` | Previous tab             |
| `ctrl+c>ctrl+w`               | Last tab                 |
| `ctrl+c>1-9`                  | Go to tab N              |
| `ctrl+c>shift+w`              | Choose window            |
| `ctrl+c>.`                    | Choose window            |
| `ctrl+c>shift+x`              | Close tab                |

### Pane/Split Management

Splits inherit the current working directory.

| Binding          | Action                           |
| ---------------- | -------------------------------- |
| `ctrl+c>v`       | Vertical split (stacked windows) |
| `ctrl+c>s`       | Horizontal split (side-by-side)  |
| `ctrl+c>h/j/k/l` | Navigate panes                   |
| `ctrl+c>x`       | Close pane                       |
| `ctrl+c>o`       | Zoom pane                        |
| `ctrl+c>-`       | Break pane to new tab            |

### Layout

| Binding          | Action        |
| ---------------- | ------------- |
| `ctrl+c>shift+\` | Rotate layout |
| `ctrl+c>=`       | Reset sizes   |

### Resize

| Binding        | Action   |
| -------------- | -------- |
| `ctrl+c>left`  | Narrower |
| `ctrl+c>right` | Wider    |
| `ctrl+c>up`    | Taller   |
| `ctrl+c>down`  | Shorter  |

### Session Management

| Binding               | Action          |
| --------------------- | --------------- |
| `ctrl+c>shift+s`      | Browse sessions |
| `ctrl+c>/`            | Browse sessions |
| `ctrl+c>d`            | Default session |
| `ctrl+c>m`            | Minimal session |
| `ctrl+c>ctrl+shift+p` | Dev session     |
| `ctrl+c>q`            | Close window    |

### Copy Mode & Misc

| Binding         | Action               |
| --------------- | -------------------- |
| `ctrl+c>enter`  | Scrollback/copy mode |
| `ctrl+c>r`      | Reload config        |
| `ctrl+c>ctrl+r` | Clear/refresh        |

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
