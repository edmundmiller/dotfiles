# Ghostty

Darwin installs the Homebrew cask; Linux uses the Ghostty flake package. Sources
live in `config/ghostty/`; the module generates config/keybindings/behavior and
symlinks other fragments. Behavior generation injects Nix PATH for GUI startup.
Darwin also generates the Stylix-backed Terminal.app `Ghostty Match` profile.

Extension options are `keybindingFiles`, `keybindingsInit`, and `configInit`.
Later keybinding fragments override earlier ones. Keybinding changes require a
full Ghostty restart; colors/fonts support reload. Use `ghostty-config` for
option details.

Startup has exactly one workspace owner: Herdr when enabled, otherwise jmux,
otherwise tmux. `~/.config/tmux/open-herdr.sh` launches Herdr, not tmux. No
fallback between owners: it recreates the Ghostty → Herdr → tmux → Herdr loop.
