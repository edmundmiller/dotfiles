{ config, lib, pkgs, ... }:

{

  nixpkgs.config = {
      yarn = pkgs.yarn.override { nodejs = pkgs.nodejs-12_x; };
  };

  environment.systemPackages = with pkgs; [
    yarn
    nodejs-12_x
  ];

  home-manager.users.emiller.xdg.configFile = {
    "zsh/rc.d/aliases.node.zsh".source = <config/node/aliases.zsh>;
    "zsh/rc.d/env.node.zsh".source = <config/node/env.zsh>;
  };
}
