# Terminal Emulator Modules

## Gotchas

- Kitty is configured through home-manager's `programs.kitty` in `kitty.nix`. The static `config/kitty/kitty.conf` is **NOT used** — edit the Nix settings instead.
- `kitty.nix` generates Catppuccin light/dark auto-theme files. The static reference to `current-theme.conf` is not part of that integration.
