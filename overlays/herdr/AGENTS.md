# Herdr Overlay

This overlay owns the repo-local Herdr package customization.

## Canonical package path

Consumers should use `pkgs.my.herdr`.

Do not add or consume top-level `pkgs.herdr`. The flake package output `.#herdr`
comes from the overlaid `pkgs.llm-agents.herdr`, and the default overlay exposes
package outputs under `pkgs.my.*` for modules.

## Why this overlays `llm-agents.herdr`

Herdr originates from the `llm-agents` input package set. This overlay replaces
that nested package so callers that intentionally inspect `pkgs.llm-agents.herdr`
see the dotfiles-patched build, while normal dotfiles modules still use the
clearer `pkgs.my.herdr` Interface.

## Patch layout

Keep source changes in `patches/*.patch`, applied in order from
`default.nix`. Prefer small single-purpose patches. If adding command behavior,
keep the command implementation and its CLI wiring together unless there is a
shared implementation Module that clearly earns its locality.

## Testing patched Herdr sources

To test a patch against the pinned upstream source, materialize the patched tree
outside the dotfiles repo and run Cargo there. Example for detector/pane tests:

```sh
set -euo pipefail
workdir=$(mktemp -d)
git clone https://github.com/ogulcancelik/herdr "$workdir/herdr"
cd "$workdir/herdr"
git checkout 4219aec638cdd81efae6460c6fba28418925c37c
git apply /Users/emiller/.config/dotfiles/overlays/herdr/patches/*.patch
cargo test \
  detect::tests::hermes \
  pane::tests::screen_chrome_overrides_codex_backend_to_hermes \
  pane::tests::screen_chrome_does_not_override_pi_process_agent
```

On macOS outside the Nix build, `cargo test` may fail before tests run while the
vendored `libghostty-vt` Zig build links against the SDK. In that case, at least
verify patch application with `git apply --check .../patches/*.patch`, or run the
tests through the Nix Herdr build environment.
