{ config, lib, pkgs, ... }:

{
  systemd.user.services.davmail = {
    wantedBy = [ "default.target" ];
    serviceConfig.ExecStart = [''
      davmail /home/emiller/.dotfiles/config/davmail/davmail.properties
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
