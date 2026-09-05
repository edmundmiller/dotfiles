# Herdr Stream Deck plugin

Upstream `timvdhoorn/stream-deck-herdr-plugin` builds an sdPlugin directory.
Rollup leaves `ws` external, so ship it beside the bundle. Redirect SDK logs to
`~/Library/Logs/ElgatoStreamDeck/`, not the read-only store.

Both Darwin hosts link the plugin with Home Manager and install the desktop app
as a Homebrew cask. Default terminal is patched to Ghostty. GUI launches need
explicit Nix system/per-user profile PATH entries for both `edmundmiller` and
`emiller`, not interactive startup files or Homebrew-only lookup.

For packaging changes, build the package; for host wiring, check affected host
outputs. Authorized activation may require a Stream Deck app restart to pick
up the linked plugin.
