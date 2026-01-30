{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.sesh;
  inherit (config.dotfiles) configDir;
in
{
  options.modules.shell.sesh = with types; {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # Sesh is installed via homebrew (joshmedeski/sesh/sesh)
    # This module manages the configuration file

    home.configFile = {
      "sesh/sesh.toml" = {
        source = "${configDir}/sesh/sesh.toml";
      };
    };
  };
}
