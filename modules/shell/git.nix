{
  config,
  options,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.shell.git;
in {
  options.modules.shell.git = {enable = mkBoolOpt false;};

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      unstable.gh
      git-open
      difftastic
      (mkIf config.modules.shell.gnupg.enable git-crypt)
      git-lfs
      pre-commit
    ];

    home.configFile = {
      "git/config".source = "${configDir}/git/config";
      "git/ignore".source = "${configDir}/git/ignore";
      "git/allowed_signers".source = "${configDir}/git/allowed_signers";
    };

    modules.shell.zsh.rcFiles = ["${configDir}/git/aliases.zsh"];
  };
}
