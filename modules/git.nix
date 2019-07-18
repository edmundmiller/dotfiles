{ config, lib, pkgs, ... }:

let
  name = "Edmund Miller";
  protonmail = "edmund.a.miller@protonmail.com";
in {
  environment.systemPackages = with pkgs; [
    gitAndTools.diff-so-fancy
    gitAndTools.git-hub
    gitAndTools.gitflow
    gitAndTools.hub
  ];
  home-manager.users.emiller = {
    programs = {
      git = {
        enable = true;
        lfs.enable = true;
        userName = "${name}";
        userEmail = "${protonmail}";
        signing.key = "BC10AA9D";
        signing.signByDefault = true;
        extraConfig = ''
          [github]
            user = emiller88
          [color]
            ui = auto
          [rebase]
            autosquash = true
          [push]
            default = current
          [merge]
            ff = onlt
            log = true
        '';
      };
    };

    # xdg.configFile = {
    #   "zsh/rc.d/aliases.git.zsh".source = <config/git/aliases.zsh>;
    # };
  };
}
