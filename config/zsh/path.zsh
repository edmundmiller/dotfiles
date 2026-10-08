# Canonical PATH order: managed Nix profiles first, then user/tool bins.
# Prevent stale npm/bun installs from shadowing managed Codex and Herdr.
typeset -U path PATH
path=(
  /etc/profiles/per-user/$USER/bin
  /run/wrappers/bin
  /run/current-system/sw/bin
  $HOME/.nix-profile/bin
  $XDG_CONFIG_HOME/dotfiles/bin
  $HOME/.pi/agent/bin
  ${BUN_INSTALL:-$HOME/.bun}/bin
  $HOME/.local/bin
  $HOME/.pixi/bin
  $HOME/.cargo/bin
  $path
)
