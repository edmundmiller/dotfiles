{ config, lib, pkgs, ... }:

with lib.my; {
  environment.systemPackages = with pkgs; [ davmail ];

  systemd.user.services.davmail = {
    wantedBy = [ "default.target" ];
    script = ''
      /run/current-system/sw/bin/davmail /home/emiller/.config/dotfiles/config/davmail/davmail.properties
    '';
    serviceConfig.Restart = "always";
  };

  home.configFile = {
    "davmail" = {
      source = "${configDir}/davmail";
      recursive = true;
    };
  };
}
