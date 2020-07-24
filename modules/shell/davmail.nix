{ config, lib, pkgs, ... }:

{
  systemd.user.services.davmail = {
    serviceConfig.ExecStart = [
      ""
      ''
        ${pkgs.davmail}/bin/davmail \
        $XDG_CONFIG_HOME/davmail/davmail.properties
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
