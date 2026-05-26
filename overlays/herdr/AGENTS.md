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
