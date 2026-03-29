# Modules

NixOS/nix-darwin modules that declare system options and configuration. Auto-discovered by `lib.mapModulesRec'` — any `.nix` file or directory with `default.nix` is loaded automatically.

## Directory Layout

| Directory   | Purpose                                        | Platform     |
| ----------- | ---------------------------------------------- | ------------ |
| `shell/`    | CLI tools, zsh, tmux, git, jj                  | All          |
| `editors/`  | Editor packages and `$EDITOR` default          | All          |
| `dev/`      | Language toolchains (node, python, rust, etc.) | All          |
| `desktop/`  | GUI apps, terminals, browsers, window managers | Mostly Linux |
| `services/` | Self-hosted services (NUC)                     | NixOS only   |
| `agenix/`   | Secret encryption/decryption via age           | All          |
| `hardware/` | Audio, bluetooth, nvidia, peripherals          | NixOS only   |
| `themes/`   | Color schemes and font config                  | All          |

## Module Pattern

Every module follows this structure:

```nix
{ config, lib, pkgs, isDarwin, ... }:
with lib; with lib.my;
let cfg = config.modules.<category>.<name>;
in {
  options.modules.<category>.<name> = {
    enable = mkBoolOpt false;
  };
  config = mkIf cfg.enable { ... };
}
```

## Key Helpers (from `lib/`)

- `mkBoolOpt` / `mkOpt` — shorthand option constructors
- `mkHost` — assembles a full host from modules
- `isDarwin` — passed as `specialArgs`, use for platform guards

## Cross-Platform Modules

Use `isDarwin` (from `specialArgs`) or `optionalAttrs (!isDarwin)` to guard NixOS-only config. See the `nix-platform-specific-options` skill for avoiding infinite recursion with `mkIf`.

## Top-Level Files

| File              | Purpose                                         |
| ----------------- | ----------------------------------------------- |
| `options.nix`     | Core options: `user`, `dotfiles`, `home`, `env` |
| `darwin-base.nix` | Shared nix-darwin config (nix settings, HM)     |
| `nixos-base.nix`  | Shared NixOS config                             |
| `security.nix`    | Security hardening                              |
| `xdg.nix`         | XDG base directory setup                        |

## Config Files vs Module Files

- **Modules** (`modules/`) declare options and wire Nix config.
- **Config files** (`config/`) hold dotfile content (zsh scripts, editor configs, etc.) that modules symlink into place via `home.configFile`.

Don't put raw config content in modules — reference `config/` paths instead.
