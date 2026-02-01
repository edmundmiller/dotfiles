# Ghostty Module

Ghostty terminal emulator configuration for nix-darwin.

## Installation

Enable in host config:

```nix
modules.desktop.term.ghostty.enable = true;
```

On macOS, Ghostty is installed via Homebrew cask (managed separately).
On Linux, the nix package is used.

## What This Module Provides

- **Config generation:** Main config, keybindings, and behavior.conf with PATH injection
- **Extensible keybindings:** Other modules can add keybindings via `keybindingFiles` or `keybindingsInit`
- **PATH injection:** Ensures nix-managed commands (like tmux) are available at startup

## Files

| Source                            | Destination                          | Notes                             |
| --------------------------------- | ------------------------------------ | --------------------------------- |
| `config/ghostty/config`           | `~/.config/ghostty/config`           | Generated (base + configInit)     |
| `config/ghostty/keybindings.conf` | `~/.config/ghostty/keybindings.conf` | Generated (files + init)          |
| `config/ghostty/behavior.conf`    | `~/.config/ghostty/behavior.conf`    | Generated (base + PATH injection) |
| `config/ghostty/macos.conf`       | `~/.config/ghostty/macos.conf`       | Symlinked                         |
| `config/ghostty/ui.conf`          | `~/.config/ghostty/ui.conf`          | Symlinked                         |

## Options

### `modules.desktop.term.ghostty.enable`

Enable the Ghostty module.

### `modules.desktop.term.ghostty.keybindingFiles`

List of keybinding files to concatenate into `keybindings.conf`.

Default: `[ "${configDir}/ghostty/keybindings.conf" ]`

Example (from another module):

```nix
modules.desktop.term.ghostty.keybindingFiles = [
  "${configDir}/ghostty/my-keybindings.conf"
];
```

### `modules.desktop.term.ghostty.keybindingsInit`

Inline keybinding text appended to `keybindings.conf`.

Example:

```nix
modules.desktop.term.ghostty.keybindingsInit = ''
  keybind = ctrl+shift+t=new_tab
'';
```

### `modules.desktop.term.ghostty.configInit`

Inline config text appended to the main config file.

Example:

```nix
modules.desktop.term.ghostty.configInit = ''
  font-size = 14
'';
```

## Extending Keybindings

Other modules (like `pi`) can add keybindings:

```nix
# Using keybindingFiles (recommended for separate files)
modules.desktop.term.ghostty.keybindingFiles = mkIf ghosttyCfg.enable [
  "${configDir}/ghostty/pi-keybindings.conf"
];

# Using keybindingsInit (for inline additions)
modules.desktop.term.ghostty.keybindingsInit = mkIf ghosttyCfg.enable ''
  keybind = alt+backspace=text:\x1b\x7f
'';
```

Use `mkBefore` to prepend or `mkAfter` to append relative to other modules.

## PATH Injection

Ghostty's `command` directive runs before shell profiles load (`--noprofile --norc`).
This module injects PATH into `behavior.conf` so nix-managed commands like `tmux` are found:

```
env=PATH=/Users/<user>/.nix-profile/bin:/etc/profiles/per-user/<user>/bin:...
```

## Troubleshooting

### tmux not found when Ghostty starts

The PATH injection should handle this. If still failing:

1. Verify `behavior.conf` contains the `env=PATH=...` line
2. Check the path includes `/etc/profiles/per-user/<username>/bin`
3. Run `hey rebuild` to regenerate configs

### Keybindings not working

1. Check `~/.config/ghostty/keybindings.conf` was generated correctly
2. Verify no syntax errors in keybinding files
3. **Fully restart Ghostty** (Cmd+Q → reopen) - keybindings require full restart

### Keybindings not updating after config reload

Ghostty caches keybindings at startup for performance. While most config changes
(colors, fonts, etc.) apply with `Ctrl+Shift+,` or `ghostty +reload-config`,
**keybindings are only parsed at launch**. You must fully quit and restart Ghostty
for keybinding changes to take effect.

### SSH shows wrong TERM

The module sets `TERM=xterm-256color` when SSH is detected (ghostty terminfo isn't widely available).
