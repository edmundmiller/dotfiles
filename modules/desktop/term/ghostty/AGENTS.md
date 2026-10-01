# Ghostty

Darwin installs the Homebrew cask; Linux uses the Ghostty flake package. Sources
live in `config/ghostty/`; the module generates config/keybindings/behavior and
symlinks other fragments. Behavior generation injects Nix PATH for GUI startup.
Darwin also generates the Stylix-backed Terminal.app `Ghostty Match` profile.

Extension options are `keybindingFiles`, `keybindingsInit`, and `configInit`.
Later keybinding fragments override earlier ones. Keybinding changes require a
full Ghostty restart; colors/fonts support reload. Use `ghostty-config` for
option details.

On Darwin, Ghostty opens a plain shell. When Herdr is enabled, `packages/herdr-app`
provides a separate app identity using a locally signed Ghostty bundle and the
shared terminal configuration. Its private XDG config includes the shared config,
then removes the global quick-terminal binding and selects `open-herdr.sh`.
The launcher clears the private XDG environment before starting Herdr. Ordinary
Ghostty owns global Cmd+grave; Darwin Cmd+1–9 selects native terminal tabs.
Keep the native bundle executable unchanged. The local signature retains hardened
runtime except library validation, which requires a team ID. A separate update
public key with no retained private key prevents upstream Sparkle installation;
manual checks can still contact upstream. Nix owns updates to both apps.
Linux startup selects Herdr when enabled, otherwise jmux, otherwise tmux.
`open-herdr.sh` launches Herdr, not tmux. Falling back between owners recreates
the Ghostty → Herdr → tmux → Herdr loop.

Run `hey check modules/desktop/term/ghostty config/ghostty` for generated config
and launcher wiring. After authorized activation, restart Ghostty for keybinding
or startup changes; a config reload covers only reloadable settings.
