# macOS defaults

`modules.desktop.macos.enable` applies shared `system.defaults` for Darwin
hosts. `default.nix` owns the values; avoid a duplicate settings inventory here.

Use first-class nix-darwin options where available, `CustomUserPreferences`
for domain/key pairs without one. The `nix-darwin-reference` skill covers option
lookup. After authorized `hey re`, inspect the affected value with
`defaults read <domain> <key>`; some settings require logout/restart despite
`activateSettings -u`.

Run `hey check --platform darwin` before activation. `defaults read` is
post-activation evidence for the exact domain/key; it does not validate Nix
option names or prove settings that require logout have taken effect.
