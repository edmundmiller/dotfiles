# Lib — Nix Helper Library

Shared utility functions exposed as `lib.my.*` throughout the flake. Auto-discovered: every `.nix` file here (except `default.nix`) is imported and merged into a single attribute set.

## Key Files

| File             | Exports                                                   | Used For                            |
| ---------------- | --------------------------------------------------------- | ----------------------------------- |
| `options.nix`    | `mkOpt`, `mkOpt'`, `mkBoolOpt`                            | Shorthand NixOS option constructors |
| `attrs.nix`      | `mapFilterAttrs`, `attrsToList`, `anyAttrs`, `countAttrs` | Attribute set manipulation          |
| `modules.nix`    | `mapModules`, `mapModulesRec`, `mapModulesRec'`           | Auto-discovery of modules and hosts |
| `nixos.nix`      | `mkHost`, `mapHosts`                                      | Building NixOS host configurations  |
| `platform.nix`   | `isDarwin`, `isLinux`, `isNixOS`, `homeBase`              | Platform detection helpers          |
| `paths.nix`      | Path manipulation utilities                               | File path helpers                   |
| `generators.nix` | Config file generators                                    | Generating config file formats      |

## How Auto-Discovery Works

`modules.nix` provides `mapModules` which scans a directory and imports every `.nix` file (excluding `default.nix`) and every subdirectory containing `default.nix`. Directories prefixed with `_` are skipped.

This is how `modules/`, `hosts/`, and `lib/` itself are auto-loaded — no manual imports needed.

## Usage in Modules

```nix
{ config, lib, ... }:
with lib;
with lib.my;  # ← brings mkBoolOpt, mkOpt, etc. into scope
```

## Adding a New Helper

Create a new `.nix` file in this directory. It receives `{ self, lib, pkgs, inputs, ... }` and should return an attribute set. It will be auto-merged into `lib.my`.
