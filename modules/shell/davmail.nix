{ config, lib, pkgs, ... }:

{
  systemd.user.services.davmail = {
    wantedBy = [ "default.target" ];
    serviceConfig.ExecStart = [''
      ${pkgs.davmail}/bin/davmail \
      /home/emiller/.config/davmail/davmail.properties
    ''];
    serviceConfig.Restart = "always";
  };

  my.home.xdg.configFile = {
    "davmail" = {
      source = <config/davmail>;
      recursive = true;
    };
  };
}
