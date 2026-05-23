{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.apps.neovide;
  configDir = config.dotfiles.configDir;
in
{
  options.modules.desktop.apps.neovide = {
    enable = mkBoolOpt false;
  };

  # The cask (`neovide-app`) is declared in the host's homebrew.nix.
  # This module just symlinks the user config file from config/neovide/.
  config = mkIf cfg.enable {
    home-manager.users.${config.user.name} = {
      home.file.".config/neovide/config.toml".source = "${configDir}/neovide/config.toml";
    };
  };
}
