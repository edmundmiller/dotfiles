{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.prise;
in
{
  options.modules.shell.prise = with types; {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # Prise is installed via homebrew on macOS
    # If you want to add it to nix packages, uncomment:
    # user.packages = [ pkgs.prise ];

    modules.shell.zsh = {
      rcFiles = [ "${configDir}/prise/aliases.zsh" ];
    };

    home.configFile = {
      "prise" = {
        source = "${configDir}/prise";
        recursive = true;
      };
    };

    env = {
      PRISE_CONFIG_DIR = "$XDG_CONFIG_HOME/prise";
    };
  };
}
