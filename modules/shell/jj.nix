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

    # Use home-manager's xdg.configFile with text to avoid source symlink issues
    home-manager.users.${config.user.name} = {
      xdg.configFile = {
        "jj/config.toml" = {
          text = builtins.readFile "${configDir}/jj/config.toml";
          force = true;
        };
        # Include conf.d files for additional configuration (credits_roll templates, etc.)
        "jj/conf.d/credits_roll.toml" = {
          text = builtins.readFile "${configDir}/jj/conf.d/credits_roll.toml";
          force = true;
        };
        "jj/conf.d/fix.toml" = {
          text = builtins.readFile "${configDir}/jj/conf.d/fix.toml";
          force = true;
        };
      };
    };

    modules.shell.zsh.rcFiles = [ "${configDir}/jj/aliases.zsh" ];
  };
}
