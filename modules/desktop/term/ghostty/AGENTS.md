# Ghostty

Darwin installs Nix `ghostty-bin`; Linux uses the Ghostty flake package. Sources
live in `config/ghostty/`; the module generates config/keybindings/behavior and
symlinks other fragments. Behavior generation injects Nix PATH for GUI startup.
Darwin also generates the Stylix-backed Terminal.app `Ghostty Match` profile.

Extension options are `keybindingFiles`, `keybindingsInit`, and `configInit`.
Later keybinding fragments override earlier ones. Keybinding changes require a
full Ghostty restart; colors/fonts support reload. Use `ghostty-config` for
option details.

Ghostty opens a plain shell on Darwin and whenever enabled Herdr uses the
`native` backend, including Linux. Native Herdr is a separate, installer-owned
signed app with its own configuration under `~/.config/herdr-app`. Its app and
`hc` are not Ghostty packages. Preserve its signed bundle unchanged.

Only the `legacy` backend installs `packages/herdr-ghostty` on Darwin. This
locally signed Ghostty copy has the distinct `Herdr Ghostty.app` identity. Its
private XDG config includes shared Ghostty configuration, removes the global
quick-terminal binding and selects `open-herdr.sh`. The launcher clears the
private XDG environment before starting legacy Herdr. Ordinary Ghostty owns
global Cmd+grave; plain-shell mode uses terminal tabs for Cmd+1 through Cmd+9.
Keep the legacy bundle executable unchanged. Its local signature retains
hardened runtime except library validation, which requires a team ID. A separate
update public key prevents upstream Sparkle installation. Nix owns Ghostty and
this legacy copy, not native Herdr updates.

Legacy Linux startup selects Herdr when enabled, otherwise jmux, otherwise tmux.
`open-herdr.sh` launches legacy Herdr, not tmux. Keep startup owners separate to
avoid the Ghostty to Herdr to tmux to Herdr loop.

Run `hey check modules/desktop/term/ghostty packages/herdr-ghostty` for generated
config and legacy bundle wiring. After authorized activation, restart Ghostty
for keybinding or startup changes; a config reload covers reloadable settings.
