{ config, lib, pkgs, ... }:

{
  programs.browserpass.enable = true;
  environment.systemPackages = with pkgs; [ firefox ];

  home-manager.users.emiller = {
    xdg.configFile = {
      # TODO install automagically
      "tridactyl/tridactylrc".source = <config/tridactyl/tridactylrc>;
    };
  };
}
