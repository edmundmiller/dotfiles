{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.mise;
  inherit (config.dotfiles) configDir;
in
{
  options.modules.shell.mise = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = [ pkgs.mise ];

    modules.shell.zsh = {
      rcInit = ''
        eval "$(mise activate zsh)"
        _cache mise completion zsh; compdef _mise mise
      '';
      rcFiles = [ "${configDir}/mise/aliases.zsh" ];
    };

    home.configFile = {
      "mise" = {
        source = "${configDir}/mise";
        recursive = true;
      };
    };
  };
}
