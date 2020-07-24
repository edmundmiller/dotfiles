{ config, lib, pkgs, ... }:

{
  systemd.user.services.davmail = {
    serviceConfig.ExecStart = [
      ""
      ''
        ${pkgs.davmail}/bin/davmail \
        /home/emiller/.config/davmail/davmail.properties
      ''
    ];
  };

  my.home.xdg.configFile = {
    "davmail" = {
      source = <config/davmail>;
      recursive = true;
    };
  };
}
