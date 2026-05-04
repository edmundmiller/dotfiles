# herdr

Nix package for upstream [ogulcancelik/herdr](https://github.com/ogulcancelik/herdr).

## Packaging model

This package intentionally installs the official upstream release binary instead of building from source.

Why:

- Upstream herdr vendors `libghostty-vt` and builds it with Zig from `build.rs`.
- On nix-darwin, that vendored Zig build currently fails to discover/use the Darwin SDK inside the sandbox.
- A source build failure blocks `hey re` because `modules.shell.herdr.package` defaults to `pkgs.my.herdr` when herdr is enabled.

So `default.nix` fetches the release asset matching `stdenvNoCC.hostPlatform.system` and installs it as `$out/bin/herdr`.

## Supported assets

The asset map in `default.nix` covers:

- `aarch64-darwin` → `herdr-macos-aarch64`
- `x86_64-darwin` → `herdr-macos-x86_64`
- `aarch64-linux` → `herdr-linux-aarch64`
- `x86_64-linux` → `herdr-linux-x86_64`

When updating herdr, refresh both the release asset names and their `sha256-*` hashes from the GitHub release metadata.

## Prefix integration

The shell module in `modules/shell/herdr.nix` owns runtime config bootstrapping and keeps `[keys].prefix` synced to `ctrl+c`, matching this dotfiles tmux prefix (`C-c` in tmux syntax).

Do not change the package to solve prefix registration issues; fix those in the module activation/config logic.

## Validation

```bash
nix build .#herdr --no-link
nix build .#darwinConfigurations.Seqeratop.config.system.build.toplevel --dry-run
```

`hey re` should not attempt to build herdr from Rust/Zig source.
