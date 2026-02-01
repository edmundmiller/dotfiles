# Ghostty Module - Agent Guide

## Purpose

Nix module for Ghostty terminal emulator. Generates config files with extensible keybindings.

## Module Structure

```
modules/desktop/term/ghostty/
├── default.nix   # Module definition
├── README.md     # Human docs
└── AGENTS.md     # This file

config/ghostty/
├── config              # Main config (includes other files)
├── keybindings.conf    # Base keybindings
├── behavior.conf       # Shell/command settings
├── macos.conf          # macOS-specific settings
├── ui.conf             # Font, colors, window settings
└── pi-keybindings.conf # Pi coding agent keybindings
```

## Key Facts

- **macOS:** Installed via Homebrew cask, not nixpkgs
- **Linux:** Uses `inputs.ghostty.packages.x86_64-linux.default`
- **Generated files:** config, keybindings.conf, behavior.conf (others symlinked)
- **PATH injection:** behavior.conf gets nix paths appended for tmux discovery

## Extension Pattern

Similar to zsh.nix rcFiles/rcInit pattern:

```nix
# Add keybinding file
modules.desktop.term.ghostty.keybindingFiles = [ "path/to/file.conf" ];

# Add inline keybindings
modules.desktop.term.ghostty.keybindingsInit = ''
  keybind = ...
'';

# Add inline config
modules.desktop.term.ghostty.configInit = ''
  font-size = 14
'';
```

## Options

| Option            | Type         | Description                           |
| ----------------- | ------------ | ------------------------------------- |
| `enable`          | bool         | Enable module                         |
| `keybindingFiles` | list of path | Files concatenated into keybindings   |
| `keybindingsInit` | lines        | Inline keybindings appended           |
| `configInit`      | lines        | Inline config appended to main config |

## Common Issues

**tmux not found** → PATH injection in behavior.conf should fix; verify after rebuild

**Keybinding conflicts** → Later files/init override earlier (pi's shift+enter vs OpenCode's)

**Keybindings not updating after reload** → Ghostty caches keybindings at startup for performance. Config reload works for colors/fonts but keybindings require full restart (Cmd+Q → reopen)

## Related Files

- `modules/shell/pi/default.nix` - Adds pi-keybindings.conf via keybindingFiles
- `modules/shell/zsh.nix` - Pattern inspiration (rcFiles/rcInit)
