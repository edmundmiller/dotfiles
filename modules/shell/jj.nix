{
  config,
  options,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.jj;
  inherit (config.dotfiles) configDir;
in
{
  options.modules.shell.jj = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      jujutsu
    ];

    # Use home-manager's xdg.configFile directly for proper activation
    home-manager.users.${config.user.name} = {
      xdg.configFile = {
        "jj/config.toml".source = "${configDir}/jj/config.toml";
      };
    };

    modules.shell.zsh.rcFiles = [ "${configDir}/jj/aliases.zsh" ];
  };
}
