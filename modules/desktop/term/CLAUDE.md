# Terminal Emulator Modules

This directory contains Nix modules for various terminal emulators.

## How Terminal Modules Work

Each terminal emulator module follows a consistent pattern:

1. **Option Definition**: Boolean `enable` flag in `options.modules.desktop.term.<terminal-name>`
2. **Conditional Configuration**: Wrapped in `mkIf cfg.enable`
3. **Package Installation**: Via home-manager or system packages
4. **Config Management**: Either via home-manager programs or direct file linking

## Kitty Terminal

### Configuration Architecture

The kitty module uses **home-manager's `programs.kitty` module** to generate configuration programmatically.

**Important**: The static config file at `config/kitty/kitty.conf` is **NOT used**. Home-manager generates the configuration from Nix settings.

### Module Location

- **Nix Module**: `modules/desktop/term/kitty.nix`
- **Static Config** (unused): `config/kitty/kitty.conf`

### Current Configuration

The module is configured with these settings (from `kitty.nix:26-35`):

```nix
home-manager.users.${config.user.name}.programs.kitty = {
  enable = true;
  settings = {
    scrollback_lines = 10000;
    scrollback_pager = ''nvim -c 'setlocal nonumber nolist showtabline=0 foldcolumn=0|Man!' -c "autocmd VimEnter * normal G" -'';
    enable_audio_bell = false;
    update_check_interval = 0;
    hide_window_decorations = true;
    notify_on_cmd_finish = "invisible 15.0";
    linux_display_server = "wayland";
    tab_bar_align = "left";
  };
};
```

### Shell Aliases

The module adds an SSH alias:

```nix
environment.shellAliases = {
  s = "kitten ssh";  # Use kitty's SSH kitten for better integration
};
```

### Customization Options

To customize kitty, you have two approaches:

#### 1. Add Settings to the Nix Module (Recommended)

Edit `modules/desktop/term/kitty.nix` and add settings to the `settings` block:

```nix
settings = {
  # ... existing settings ...
  font_family = "Fira Code";
  font_size = 12;
  background_opacity = 0.95;
  # See: https://sw.kovidgoyal.net/kitty/conf.html
};
```

#### 2. Use extraConfig for Freeform Configuration

For complex configurations that don't map well to Nix attributes:

```nix
home-manager.users.${config.user.name}.programs.kitty = {
  enable = true;
  settings = { ... };
  extraConfig = ''
    # Custom kitty configuration
    map ctrl+shift+t new_tab_with_cwd
    map ctrl+shift+enter new_window_with_cwd
  '';
};
```

### Session Management

**Status**: Fully implemented with hybrid approach combining session persistence and dynamic project creation.

#### Session Files

Session files are located in `config/kitty/sessions/` and define complete terminal layouts:

- **`default.kitty-session`** - Auto-save/restore session (automatically updated when you save)
- **`minimal.kitty-session`** - Single-window layout
- **`dev.kitty-session`** - Development layout (editor + shell + test panel)
- **`project.kitty-session`** - Multi-tab template (editor, tests, logs)

#### Session Keybindings

All keybindings use **Ctrl+A** as the prefix key (tmux-style).

**Session Management:**

- `Ctrl+A > S` - Save current layout to default session
- `Ctrl+A > D` - Load default session
- `Ctrl+A > M` - Load minimal session
- `Ctrl+A > P` - Load dev session
- `Ctrl+A > /` - Browse all sessions
- `Ctrl+A > -` - Previous session

**Window/Tab Management:**

- `Ctrl+A > Enter` - New tab in current directory
- `Ctrl+A > N` - New tab with cwd
- `Ctrl+A > W` - Close tab
- `Ctrl+A > Minus` - Horizontal split
- `Ctrl+A > |` - Vertical split

**Window Navigation (vim-style):**

- `Ctrl+A > H/J/K/L` - Navigate windows (left/down/up/right)
- `Ctrl+A > Arrows` - Resize windows

**Dynamic Project Creation:**

- `Ctrl+A > 1` - Create 1-window project tab
- `Ctrl+A > 2` - Create 2-window project tab (editor + shell)
- `Ctrl+A > 3` - Create 3-window project tab (editor + shell + logs)

#### Custom Project Kitten

The `new_project.py` kitten (`config/kitty/new_project.py`) provides dynamic project-based tab creation inspired by andrew.hau.st's workflow. It creates new tabs with predefined layouts based on the number key pressed.

**Future enhancements:**

- Integration with autojump/zoxide for project selection
- Session picker TUI
- Workspace-specific sessions (seqera, nfcore, phd, etc.)
- Auto-launch nvim in editor windows

#### Session Workflow

**Typical workflow:**

1. Arrange your windows/tabs as desired
2. Press `Ctrl+A > S` to save to default session
3. Close kitty - session will auto-restore on next launch
4. Switch between saved sessions with `Ctrl+A > [D/M/P]`
5. Create new project layouts on-the-fly with `Ctrl+A > [1/2/3]`

**Session files** support:

- Multiple tabs with custom titles
- Complex window layouts using splits
- Custom working directories per window
- Window focus management
- Environment variable expansion

See [Kitty Sessions Documentation](https://sw.kovidgoyal.net/kitty/sessions/) for advanced session file syntax.

### Theme Integration

**Current Status**: Theme integration is **not** implemented.

The static config at `config/kitty/kitty.conf` previously referenced `current-theme.conf`, but this file doesn't exist and isn't generated by the theme system.

**To add theme support:**

1. Generate kitty color scheme from active theme in `modules/theme/default.nix`
2. Add kitty-specific theme overrides in theme modules (e.g., `modules/themes/alucard/default.nix`)
3. Use `programs.kitty.settings` to set theme colors dynamically

Example theme integration:

```nix
# In modules/theme/default.nix or theme-specific module
home-manager.users.${config.user.name}.programs.kitty.settings = {
  foreground = "#${config.modules.theme.colors.foreground}";
  background = "#${config.modules.theme.colors.background}";
  # ... more theme colors
};
```

### References

- [Kitty Configuration Docs](https://sw.kovidgoyal.net/kitty/conf.html)
- [Home-Manager Kitty Options](https://nix-community.github.io/home-manager/options.xhtml#opt-programs.kitty.enable)

## Other Terminal Emulators

### Ghostty

- Uses Homebrew installation on macOS
- Config linked from `config/ghostty/`
- Includes tmux wrapper for auto-attach behavior

### Wezterm

- Uses flake input: `inputs.wezterm.packages`
- Home-manager module: `programs.wezterm`
- Currently minimal configuration

### Simple Terminal (st)

- Creates desktop entry
- Adds terminal compatibility wrapper
- Uses xst (st + extensions)

## Enabling Terminal Emulators

In your host configuration (`hosts/<hostname>/default.nix`):

```nix
modules = {
  desktop.term.ghostty.enable = true;  # Enable ghostty
  desktop.term.kitty.enable = true;    # Enable kitty
  # ... other modules
};
```

Multiple terminal emulators can be enabled simultaneously. The default terminal is set via the `desktop.term.default` module based on which terminal is enabled.
