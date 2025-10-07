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
  cfg = config.modules.shell.git;
in
{
  options.modules.shell.git = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      git-open
      difftastic
      (mkIf config.modules.shell.gnupg.enable git-crypt)
      git-lfs
      pre-commit
    ];

    # Use home-manager's xdg.configFile directly for proper activation
    home-manager.users.${config.user.name} = {
      xdg.configFile = {
        "git/config".source = "${configDir}/git/config";
        "git/ignore".source = "${configDir}/git/ignore";
        "git/allowed_signers".source = "${configDir}/git/allowed_signers";
        # GitHub CLI config
        "gh/config.yml".source = "${configDir}/gh/config.yml";
        "gh/hosts.yml".source = "${configDir}/gh/hosts.yml";
        # GitHub Dashboard config
        "gh-dash/config.yml".source = "${configDir}/gh-dash/config.yml";
      };
    };

    modules.shell.zsh.rcFiles = [ "${configDir}/git/aliases.zsh" ];
  };
}
