{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.direnv;
  inherit (config.dotfiles) configDir;
in
{
  options.modules.shell.direnv = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = [ pkgs.direnv ];
    modules.shell.zsh.rcInit = ''eval "$(direnv hook zsh)"'';

    home.configFile = {
      "direnv" = {
        source = "${configDir}/direnv";
        recursive = true;
      };
    };
  };
}
