# Hunk Overlay

This overlay owns repo-local Hunk package customization.

## Canonical package path

Consumers should use `pkgs.my.hunk`.

Do not add or consume top-level `pkgs.hunk`. The flake package output `.#hunk`
comes from the overlaid `pkgs.llm-agents.hunk`, and the default overlay exposes
package outputs under `pkgs.my.*` for modules.

## Why this overlays `llm-agents.hunk`

Hunk originates from the `llm-agents` input package set. This overlay replaces
that nested package so future patches, wrappers, or source pins live in one
local seam while preserving a clear consumer Interface: `pkgs.my.hunk`.
