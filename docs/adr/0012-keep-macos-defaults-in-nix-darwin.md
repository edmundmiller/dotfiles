---
purpose: Record why nix-darwin remains the owner of macOS preferences instead of mise bootstrap.
applies_to: macOS preference declarations and future mise defaults integration.
entrypoint: Manage preferences in modules/desktop/macos/default.nix.
verification: Check that each managed preference has one writer and any mise declarations derive from Nix.
update_when: A concrete drift-checking, nested-preference, or Dock-layout need warrants mise integration.
---

# ADR 0012: Keep macOS defaults in nix-darwin

## Status

Accepted, 2026-10-12.

## Decision

Keep nix-darwin's `system.defaults` as the owner of our existing macOS
preferences. Use first-class options where available and
`CustomUserPreferences` for other domain/key pairs. Do not add mise defaults
configuration or activation wiring now.

[Mise's macOS defaults support](https://mise.jdx.dev/bootstrap/macos-defaults.html)
overlaps with our existing [macOS module](../../modules/desktop/macos/default.nix).
Migrating those settings adds no needed behavior, while declaring them in both
systems creates competing writers whose last application wins.

## Revisit criteria

Consider a narrow mise integration when we need one of these capabilities:

- Drift reporting and dry runs for declared preferences. Mise status only checks
  its own declarations, so it cannot directly audit nix-darwin configuration.
  Generate any audit declarations from Nix rather than maintain a second inventory,
  and keep the audit read-only for preferences nix-darwin owns.
- Updating a nested dictionary entry, such as one keyboard shortcut, while
  preserving unrelated entries and their types.
- Reconciling pinned Dock applications while preserving existing tile metadata
  and unrelated tiles. Our current `static-only` Dock does not justify this work.

If mise becomes a writer, give it explicitly assigned preferences and remove
overlapping nix-darwin writes. Treat a shared dictionary as one preference for
ownership purposes, even when mise edits only one nested value. Nix should remain
the source of truth for generated mise configuration. Apply preferences as the
target user on macOS, never during a Nix build.

Deferring mise means we do not gain its drift checks today. Removing a mise
declaration would also leave the live value in place, so future adoption must
include an explicit restore or deletion plan rather than assume removal rolls
back preferences.

## References

- [Mise macOS defaults documentation](https://mise.jdx.dev/bootstrap/macos-defaults.html), accessed 2026-10-12.
- [Originating discussion](https://ampcode.com/threads/T-01a12cd7-f435-771b-8558-9d8b06edc8f1).
