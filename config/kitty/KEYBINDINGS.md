# Kitty Keybindings (Tmux-Style)

Prefix: `ctrl+a` (like tmux with C-c prefix)

Based on [hlissner/dotfiles tmux.conf](https://github.com/hlissner/dotfiles/blob/master/config/tmux/tmux.conf)

## Quick Reference

### Window/Tab Management

| Binding | Action | Tmux Equivalent |
|---------|--------|-----------------|
| `ctrl+a>c` | New tab | `C-c c` |
| `ctrl+a>ctrl+n` | Next tab | `C-c C-n` |
| `ctrl+a>ctrl+p` | Previous tab | `C-c C-p` |
| `ctrl+a>ctrl+w` | Last tab | `C-c C-w` |
| `ctrl+a>1-9` | Go to tab N | `C-c 1-9` |
| `ctrl+a>shift+w` | Choose window | `C-c W` |
| `ctrl+a>.` | Choose window | `C-c .` |
| `ctrl+a>shift+x` | Close tab | `C-c X` |

### Pane/Split Management

| Binding | Action | Tmux Equivalent |
|---------|--------|-----------------|
| `ctrl+a>v` | Vertical split | `C-c v` |
| `ctrl+a>s` | Horizontal split | `C-c s` |
| `ctrl+a>h/j/k/l` | Navigate panes | `C-c h/j/k/l` |
| `ctrl+a>x` | Close pane | `C-c x` |
| `ctrl+a>o` | Zoom pane | `C-c o` |
| `ctrl+a>-` | Break pane to new tab | `C-c -` |

### Layout

| Binding | Action | Tmux Equivalent |
|---------|--------|-----------------|
| `ctrl+a>shift+\` | Rotate layout | `C-c \|` |
| `ctrl+a>=` | Reset sizes | `C-c =` |

### Resize

| Binding | Action |
|---------|--------|
| `ctrl+a>left` | Narrower |
| `ctrl+a>right` | Wider |
| `ctrl+a>up` | Taller |
| `ctrl+a>down` | Shorter |

### Session Management

| Binding | Action | Tmux Equivalent |
|---------|--------|-----------------|
| `ctrl+a>shift+s` | Browse sessions | `C-c S` |
| `ctrl+a>/` | Browse sessions | `C-c /` |
| `ctrl+a>d` | Default session | `C-c d` (detach) |
| `ctrl+a>m` | Minimal session | - |
| `ctrl+a>ctrl+shift+p` | Dev session | - |
| `ctrl+a>q` | Close window | `C-c q` |

### Copy Mode & Misc

| Binding | Action | Tmux Equivalent |
|---------|--------|-----------------|
| `ctrl+a>enter` | Scrollback/copy mode | `C-c Enter` |
| `ctrl+a>r` | Reload config | `C-c r` |
| `ctrl+a>ctrl+r` | Clear/refresh | `C-c C-r` |

### Custom (Project Scripts)

| Binding | Action |
|---------|--------|
| `ctrl+a>shift+1` | Project script 1 |
| `ctrl+a>shift+2` | Project script 2 |
| `ctrl+a>shift+3` | Project script 3 |

## Philosophy

- Single letters for common ops (`c`, `v`, `s`, `h/j/k/l`)
- Capital/shift for destructive ops (`X` close, `S` session)
- Hold prefix (`ctrl+n/p/w`) for rapid switching
- Numbers for direct access

## Future Enhancements

- [ ] Vim-aware `C-h/j/k/l` navigation (no prefix)
- [ ] `ctrl+a>u/U` for jjui splits
- [ ] `ctrl+a>shift+c` for custom command prompt
