# kittylitter

Patched package for `dnakov/litter`'s `kittylitter` daemon, with a local patch applied to the `dnakov/alleycat` Pi bridge.

## Why this exists

Upstream Alleycat currently tries to hydrate Pi sessions by calling a speculative Pi RPC command:

```json
{ "type": "list_sessions", "allProjects": true }
```

Released Pi builds, including `@earendil-works/pi-coding-agent@0.74.0`, return `Unknown command: list_sessions`. For local kittylitter daemon usage, Alleycat can read `~/.pi/agent/sessions` directly, so this package patches local mode to use filesystem hydration instead of spawning Pi for `list_sessions` during startup.

The patch also switches `extension_ui_request` method decoding to camelCase so Pi status/widget frames like `setWidget`, `setStatus`, and `setTitle` do not spam parse warnings.

## Files

- `default.nix` — builds `dnakov/litter` `v0.3.0` and vendors a pinned `dnakov/alleycat` source.
- `patches/0001-pi-bridge-local-hydration-and-ui-camelcase.patch` — local Alleycat compatibility patch.

## Common commands

Build:

```sh
nix build .#kittylitter --no-link
```

Print pairing QR code using this patched package. Prefer resolving the built binary explicitly; this mirrors the direct `/nix/store/.../bin/kittylitter pair --qr` form that is known to work:

```sh
$(nix build .#kittylitter --no-link --print-out-paths)/bin/kittylitter pair --qr
```

Install/update launchd autostart to the patched binary:

```sh
$(nix build .#kittylitter --no-link --print-out-paths)/bin/kittylitter install
launchctl kickstart -k gui/$(id -u)/com.sigkitten.kittylitter
```

Check status:

```sh
$(nix build .#kittylitter --no-link --print-out-paths)/bin/kittylitter status
```

Probe Pi sessions:

```sh
$(nix build .#kittylitter --no-link --print-out-paths)/bin/kittylitter probe --agent pi --method thread/list
```

## Host deployment

`modules/services/kittylitter/default.nix` runs this package when `modules.services.kittylitter.enable = true`:

- NixOS: Home Manager user systemd service named `kittylitter.service`.
- macOS/nix-darwin: user launchd agent named `kittylitter`.

The service preserves the existing `~/.config/kittylitter/host.toml` token and patches `[agents.pi].enabled = true` at startup.

## Patch policy

Keep upstream source changes in `patches/*.patch`; do not inline large rewrites in `postPatch`. If upstream Alleycat fixes this, prefer dropping the patch and bumping the pinned Alleycat/litter revisions.
