{ config, lib, pkgs, ... }:

let
  name = "Edmund Miller";
  protonmail = "edmund.a.miller@protonmail.com";
in {
  my = {
    packages = with pkgs; [ gitAndTools.hub gitAndTools.diff-so-fancy ];
    zsh.rc = lib.readFile <config/git/aliases.zsh>;
    # TODO Move away from home-manager to configure this
    # Do recursively, in case git stores files in this folder
    # home.xdg.configFile = {
    # "git/config".source = <config/git/config>;
    # "git/ignore".source = <config/git/ignore>;
    # };

    home = {
      programs = {
        git = {
          enable = true;
          lfs.enable = true;
          userName = "${name}";
          userEmail = "${protonmail}";
          signing.key = "BC10AA9D";
          signing.signByDefault = true;
          extraConfig = {
            github = { user = "emiller88"; };
            gitlab = { user = "emiller88"; };
            color = { ui = "auto"; };
            rebase = { autosquash = "true"; };
            push = { default = "current"; };
            merge = {
              ff = "onlt";
              log = "true";
            };
          };
          ignores = [ ".direnv" ".envrc" ];
        };
      };
    };
  };
}
