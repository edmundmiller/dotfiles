# macOS defaults

`modules.desktop.macos.enable` applies shared `system.defaults` for Darwin
hosts. `default.nix` owns the values; avoid a duplicate settings inventory here.

Use first-class nix-darwin options where available, `CustomUserPreferences`
for domain/key pairs without one. The `nix-darwin-reference` skill covers option
lookup. After authorized `hey re`, inspect the affected value with
`defaults read <domain> <key>`; some settings require logout/restart despite
`activateSettings -u`.
