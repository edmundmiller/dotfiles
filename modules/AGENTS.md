# Nix modules

Modules declare `modules.<category>.<name>` options and wire configuration;
dotfile content belongs in `config/`. Recursive discovery loads `.nix` files
and directories with `default.nix`; `_`-prefixed directories are excluded.

Use `lib.my.mkBoolOpt` / `mkOpt` and `mkIf cfg.enable` for optional features.
`isDarwin` comes from `specialArgs`; omit NixOS-only option names with
`optionalAttrs (!isDarwin)`, not a false `mkIf` around nonexistent options.
The `nix-platform-specific-options` skill explains platform evaluation pitfalls.

`options.nix` owns `user`, `dotfiles`, `home`, and `env`; `darwin-base.nix` and
`nixos-base.nix` own platform defaults. Agent runtimes live under `agents/`,
CLI tools under `shell/`, and hosted services under `services/`.
