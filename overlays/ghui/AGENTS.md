# ghui overlay

Upstream's flake exports only a devShell. This overlay builds `pkgs.my.ghui`
from its input source and takes `inputs`, so `flake.nix` imports it explicitly
rather than through generic overlay discovery.

The input rev and `package-harness.json` ref must match. The fork pin carries
PR #43's hunk navigation/copy behavior; consider upstream when that lands.
`pkg-check ghui` covers typecheck and targeted tests, including the carried
Review Box command/palette/`b` binding patch.

`bun.nix` is generated from the pinned checkout using `bun2nix`; regenerate it
when `bun.lock` changes. It must be copied into the source tree for relative
`@ghui/keymap` workspace paths to resolve.
