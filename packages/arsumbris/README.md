# Ars Umbris

This package supplies an explicit source installer and launcher, **not a
sandboxed, prebuilt Electron application**. Upstream 0.0.1-alpha requires writable
sibling repositories and downloads/builds its dependencies during setup.

From the dotfiles checkout:

```sh
nix run .#arsumbris -- setup
nix run .#arsumbris -- dev
```

The package is auto-discovered as `pkgs.my.arsumbris`; it is not enabled globally
or run at activation. Setup uses Node 24 (`node-lts`), pnpm 11.1.1, Rust, Git, and
Python from Nix without replacing the global toolchain. Xcode Command Line Tools
must already be installed. Claude Code or Codex is optional for agent features
and must be available on the caller's PATH.

Native Node modules use Command Line Tools' `/usr/bin/python3`: Nix Python's
libffi callback allocation crashes on macOS 27 during the node-gyp build.

Setup creates `~/arsumbris` for the 22 sibling repositories and `~/.arsumbris` for
device configuration and the engine binary. Existing destinations must be clean
upstream checkouts at the pinned revision; otherwise it stops without modifying
them. Resolve mismatches manually; setup never resets or updates a checkout.
Upstream's seeder preserves existing config entries, but can remove YAML comments.
Existing tool paths are not replaced: inspect `~/.arsumbris/au-host/config/paths.yaml`
if migrating a previous installation.

The launcher preserves the pinned Node/pnpm environment for nested commands.
Setup does not launch the GUI. No upstream application build or installation
runs as part of `nix build`.

Upstream references: [INSTALL.md](https://github.com/arsumbris/arsumbris/blob/a9f6cceedb191b8504443222d55d3106f9f36ba9/INSTALL.md)
and [SAFETY.md](https://github.com/arsumbris/arsumbris/blob/a9f6cceedb191b8504443222d55d3106f9f36ba9/SAFETY.md).
The alpha has **no sandbox**: installed plugins, projections, and agents execute
with your user privileges. The dotfiles wrapper's MIT license does not grant
rights to upstream components, which carry their own terms.
