# jjui Configuration

Terminal UI for [jj](https://github.com/martinvonz/jj) version control.

## Installation

jjui is installed via homebrew in the nix-darwin configuration. The config is symlinked to `~/.config/jjui/config.toml`.

## Theme

Using **Catppuccin Mocha** - a warm, dark theme with good contrast. Colors sourced from [tinted-jjui](https://github.com/vic/tinted-jjui).

## Key Bindings

### Key Sequences (press first key, see overlay, press second)

| Sequence | Action                         |
| -------- | ------------------------------ |
| `a d`    | AI-generated commit message    |
| `a e`    | AI commit message (with edit)  |
| `g s`    | Git sync (fetch all remotes)   |
| `g P`    | Git push with named branch     |
| `w w`    | Mark as WIP                    |
| `w t`    | Tug (move bookmark to current) |
| `w r`    | Retrunk (rebase onto trunk)    |
| `w c`    | Cleanup empty commits          |
| `w d`    | Tidy (safe cleanup)            |
| `p p`    | PR preview in neovim           |
| `p s`    | Stacked pull requests          |

### Single Keys

| Key      | Action                           |
| -------- | -------------------------------- |
| `Y`      | Yank (context-aware clipboard)   |
| `O`      | Open file in editor              |
| `ctrl+l` | Quick revset switcher menu       |
| `alt+j`  | Move commit down (before parent) |
| `alt+k`  | Move commit up (after child)     |

### Default Keys (built-in)

| Key      | Action          |
| -------- | --------------- |
| `?`      | Help            |
| `q`      | Quit            |
| `p`      | Toggle preview  |
| `L`      | Change revset   |
| `:`      | Execute jj cmd  |
| `$`      | Execute shell   |
| `x`      | Custom commands |
| `ctrl+r` | Refresh         |

## Preview Pane

- **Position**: Auto (right on wide terminals, bottom on narrow)
- **Width**: 50% (adjustable with `ctrl+h` / `ctrl+l`)
- **Show at start**: No (toggle with `p`)

## Customization

### Change Theme

Replace `[ui.colors]` section with colors from [tinted-jjui](https://github.com/vic/tinted-jjui) (462 themes available).

### Add Custom Commands

```toml
[custom_commands."my command"]
key_sequence = ["m", "c"]  # or key = ["M"] for single key
desc = "Description shown in menu"
args = ["jj", "subcommand", "args"]  # or use lua = '''...'''
```

### Override Log Template

```toml
[revisions]
template = 'builtin_log_compact'  # or custom template
```

## Troubleshooting

**Keys not working?**

- Check for conflicts with terminal emulator shortcuts
- `alt+` keys may need terminal configuration (iTerm2: Profiles > Keys > Option as Meta)

**Theme looks wrong?**

- Ensure terminal supports true color (24-bit)
- Check `$TERM` is set to something like `xterm-256color` or `tmux-256color`

**Custom commands failing?**

- Check jj aliases exist: `jj config list aliases`
- For Lua commands, check syntax with `jjui --check-config`

## Resources

- [jjui Documentation](https://idursun.github.io/jjui/)
- [Lua API Wiki](https://github.com/idursun/jjui/wiki/Custom-Command-%E2%80%90-Lua-Scripting)
- [tinted-jjui Themes](https://github.com/vic/tinted-jjui)
