# macOS System Defaults Module

Opinionated `system.defaults` for all Darwin hosts. Enable: `modules.desktop.macos.enable = true;`

## What It Manages

| Category | Key settings                                                                                                                             |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Dock     | autohide, left, static-only, no recents, hot corners off                                                                                 |
| Finder   | POSIX path title, all extensions, pathbar, statusbar, quit menu, folders first                                                           |
| Trackpad | tap-to-click, 3-finger drag                                                                                                              |
| Keyboard | full keyboard control (mode 3), fast repeat (15/2), press-and-hold off                                                                   |
| Text     | all auto-corrections off (caps, dashes, periods, quotes, spelling)                                                                       |
| Login    | no guest, show full name                                                                                                                 |
| Privacy  | Siri off, personalized ads off                                                                                                           |
| Misc     | no DS_Store on network/USB, Photos hotplug off, screencapture PNG, lock on screensaver, expanded save panels, click-wallpaper-reveal off |

## Discovering Available Options

### First-class nix-darwin options

Browse all `system.defaults.*` options:

```bash
# search nix-darwin options online
# https://daiderd.com/nix-darwin/manual/index.html

# or locally — list all system.defaults sub-options
nix eval '.#darwinConfigurations.MacTraitor-Pro.options.system.defaults' --apply 'builtins.attrNames' 2>/dev/null
```

Notable submodules: `dock`, `finder`, `trackpad`, `NSGlobalDomain`, `loginwindow`, `menuExtraClock`, `screencapture`, `screensaver`, `spaces`, `WindowManager`, `universalaccess`.

### CustomUserPreferences (escape hatch)

For anything without a first-class option, use `system.defaults.CustomUserPreferences`:

```nix
system.defaults.CustomUserPreferences = {
  "com.apple.SomeApp" = {
    SomeKey = value;
  };
};
```

Find domain/key pairs with:

```bash
# read all prefs for a domain
defaults read com.apple.dock

# find which domain owns a key
defaults find "SomeKey"

# read current value
defaults read com.apple.dock autohide

# monitor real-time changes (useful to discover keys)
# change a setting in System Settings, then diff before/after:
defaults read > /tmp/before.plist
# ... change setting ...
defaults read > /tmp/after.plist
diff /tmp/before.plist /tmp/after.plist
```

### Reference material

- [nix-darwin manual (system.defaults)](https://daiderd.com/nix-darwin/manual/index.html) — canonical option docs
- [macos-defaults.com](https://macos-defaults.com/) — visual gallery of `defaults write` settings with screenshots
- [github.com/yannbertrand/macos-defaults](https://github.com/yannbertrand/macos-defaults) — source for above
- [ryan4yin/nix-darwin-kickstarter](https://github.com/ryan4yin/nix-darwin-kickstarter/blob/main/rich-demo/modules/system.nix) — good reference config
- [mathiasbynens/dotfiles .macos](https://github.com/mathiasbynens/dotfiles/blob/main/.macos) — comprehensive `defaults write` reference (not nix, but maps 1:1)

### Verifying applied settings

```bash
# check a specific value took effect
defaults read com.apple.dock autohide
defaults read NSGlobalDomain NSAutomaticSpellingCorrectionEnabled
defaults read com.apple.assistant.support "Assistant Enabled"

# some settings need a logout/restart to take effect
# nix-darwin runs `activateSettings -u` which handles most
```

## Adding New Settings

1. Check if nix-darwin has a first-class option (search the manual)
2. If yes, add to the appropriate `system.defaults.<section>` block
3. If no, add to `CustomUserPreferences` with the `defaults` domain and key
4. Rebuild with `hey re` and verify with `defaults read`

## Files

- `default.nix` — module definition
- `AGENTS.md` — this file
