{ config, lib, pkgs, ... }:

{
  programs.browserpass.enable = true;
  environment = {
    sessionVariables = {
      BROWSER = "firefox";
      XDG_DESKTOP_DIR = "$HOME"; # prevent firefox creating ~/Desktop
    };

    systemPackages = with pkgs; [
      firefox
      (pkgs.writeScriptBin "firefox-private" ''
        #! ${pkgs.bash}/bin/bash
        firefox --private-window "$@"
      '')
      tridactyl-native
    ];
  };

  home-manager.users.emiller = {
    xdg.configFile = {
      # TODO install automagically
      "tridactyl/tridactylrc".source = <config/tridactyl/tridactylrc>;
    };
  };
}
