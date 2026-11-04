# Herdr deployment

`default.nix` declares shared options and gates the old TUI deployment behind
`backend = "legacy"`. Native is the default on both platforms. `native.nix`
checks the installer-owned `hc`; `native.app.enable` defaults to Darwin and
gates app preferences, mods and helpers. Servers
receive core-only configuration. Changing backend leaves all sessions and old
configuration untouched.

Native activation reconciles only managed leaves of settings, keys and
programs. Keep these writable and preserve other preferences. Deploy only
personally named mods; shipped assets, app state and generated files remain
app-owned. Preserve the native signed bundle. Missing binaries produce an
installation hint, not a network install during activation.

Legacy activation alone installs marketplace plugins, old agent integrations,
smart rename and Projects. `hermes.nix` must remain legacy-gated because its
installer speaks the old protocol. Pi's native OSC 7501 reporting needs no
legacy integration. Verify other agents' protocol support before claiming
native status reporting works.

`piThemeName` remains a compatibility option for legacy Pi wiring. Native
Herdr owns its terminal palette and must not force a Ghostty-tuned Pi theme.
The Ghostty module owns the renamed `packages/herdr-ghostty` legacy frontend;
it never launches native Herdr inside a terminal.

Run `hey check modules/shell/herdr config/herdr` and the native CLI/config
behavior tests. Legacy `_tests/` still checks TOML against the old binary;
it does not validate native JSON or mods. Add Darwin evaluation for backend
or cross-module wiring changes. Keep private tnote disabled in VM tests.
