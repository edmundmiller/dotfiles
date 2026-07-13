---
purpose: Package and deploy the Herdr Stream Deck plugin.
applies_to: Changes under packages/stream-deck-herdr-plugin or its host links.
entrypoint: packages/stream-deck-herdr-plugin/default.nix
verification: Build the package and both Darwin host configurations.
update_when: Packaging, runtime dependencies, or host deployment changes.
---

# stream-deck-herdr-plugin

Nix package for upstream [timvdhoorn/stream-deck-herdr-plugin](https://github.com/timvdhoorn/stream-deck-herdr-plugin), an Elgato Stream Deck plugin that mirrors Herdr agent status.

## Host deployment

This package is installed on both managed macOS hosts via Home Manager file links:

- `hosts/seqeratop/default.nix`
- `hosts/mactraitorpro/default.nix`

The Stream Deck desktop app itself is installed as the Homebrew cask `elgato-stream-deck` in each host's `homebrew.nix`.

## Packaging notes

- Upstream source is fetched from GitHub and built with Bun using the checked-in `bun.lock`.
- Build output is the upstream `dev.timvdhoorn.herdr-agents.sdPlugin` directory copied into the Nix store.
- The Rollup bundle leaves `ws` external, so the package copies that runtime dependency beside the plugin.
- The package redirects SDK logs to `~/Library/Logs/ElgatoStreamDeck/` because the plugin runs from the read-only Nix store.
- The package intentionally patches the plugin's default terminal activator from `iTerm` to `Ghostty`, because both hosts run Herdr in Ghostty and Stream Deck launches plugins with a sparse GUI environment where shell env vars may not be present.
- Keep this as a directory package (`packages/stream-deck-herdr-plugin/default.nix`) so future patches/docs can live alongside it.

## Updating

1. Update `rev` in `default.nix` to the desired upstream commit.
2. Set `hash = lib.fakeHash;` and run:
   ```sh
   nix build .#stream-deck-herdr-plugin --no-link
   ```
3. Copy the reported `got: sha256-...` hash into `default.nix`.
4. Rebuild and smoke-check:
   ```sh
   nix build .#stream-deck-herdr-plugin --no-link
   nix build .#darwinConfigurations.Seqeratop.config.system.build.toplevel --no-link
   ```

## Manual verification after rebuild

After `hey re` / `darwin-rebuild`, restart the Stream Deck app if it does not pick up the linked plugin automatically. In the Stream Deck app, drag the plugin's `herdr` actions onto keys.

Recommended 6-key Mini layout from upstream:

```text
[ Agent Slot 0 ][ Agent Slot 1 ][ Agent Slot 2 ]
[ Agent Slot 3 ][ Agent Slot 4 ][    Pager      ]
```

## Gotchas

- The plugin shells out to `herdr`, so Herdr must be installed and usable by the GUI-launched plugin process. The package patches upstream's Homebrew-only PATH to include nix-darwin system/per-user profiles (`/run/current-system/sw/bin`, `/etc/profiles/per-user/{edmundmiller,emiller}/bin`, `/nix/var/nix/profiles/default/bin`). If Herdr ever stops being found, prefer fixing this package environment deliberately rather than relying on interactive shell startup files.
- `HERDR_DECK_TERMINAL_APP` can override the terminal app upstream, but this package bakes in `Ghostty` as the default. Only change that patch if the host terminal strategy changes.
- Do not vendor upstream source into this repo unless local patches become too large for simple Nix patching.
