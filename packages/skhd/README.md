---
purpose: Reserve the pkgs.my.skhd package boundary for skhd.zig.
applies_to: Replacing the temporary Homebrew installation with a native Nix package.
entrypoint: hosts/mactraitorpro/homebrew.nix
verification: Run skhd --status and the terminal-launcher regression test.
update_when: packages/skhd/default.nix becomes buildable.
---

# skhd.zig package

The live Darwin host temporarily installs `jackielii/tap/skhd-zig` through
Homebrew. This directory becomes the auto-discovered `pkgs.my.skhd` package
when `default.nix` lands; the adjacent `# ponytail:` marker identifies the
fallback to remove at that point.
