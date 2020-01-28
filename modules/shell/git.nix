{ config, lib, pkgs, ... }:

let
  name = "Edmund Miller";
  protonmail = "edmund.a.miller@protonmail.com";
in {
  my = {
    packages = with pkgs; [ git-lfs gitAndTools.hub gitAndTools.diff-so-fancy ];
    zsh.rc = lib.readFile <config/git/aliases.zsh>;
    # Do recursively, in case git stores files in this folder
    home.xdg.configFile = {
      "git/config".source = <config/git/config>;
      "git/ignore".source = <config/git/ignore>;
    };
  };
}
