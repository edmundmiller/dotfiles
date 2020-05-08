{ config, lib, pkgs, ... }:

with lib; {
  options.modules.shell.git = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.modules.shell.git.enable {
    my = {
      packages = with pkgs; [
        git-lfs
        gitAndTools.hub
        gitAndTools.diff-so-fancy
        gitAndTools.gitFull
      ];
      zsh.rc = lib.readFile <config/git/aliases.zsh>;
      # Do recursively, in case git stores files in this folder
      home.xdg.configFile = {
        "git/config".source = <config/git/config>;
        "git/ignore".source = <config/git/ignore>;
      };
    };
  };
}
