# Ghostty

Darwin installs Nix `ghostty-bin`; Linux uses the Ghostty flake package. Sources live in `config/ghostty/`; the module generates config/keybindings/behavior and symlinks other fragments. Behavior generation injects Nix PATH for GUI startup. Darwin also generates the Stylix-backed Terminal.app `Ghostty Match` profile.

Extension options are `keybindingFiles`, `keybindingsInit`, and `configInit`. Later keybinding fragments override earlier ones. Keybinding changes require a full Ghostty restart; colors/fonts support reload. Use `ghostty-config` for option details.

Ghostty opens a plain shell on every platform. Cmd+1 through Cmd+9 select terminal tabs. Herdr is a separate, installer-owned native app under `~/.config/herdr-app`; preserve its signed bundle unchanged. There is no legacy frontend or multiplexer startup launcher.

Run `hey check modules/desktop/term/ghostty config/ghostty` for generated configuration. Restart Ghostty only after authorized activation; source checks do not change the running app.
