{ config, lib, pkgs, ... }:

let imapfilterconfig = "/home/emiller/.config/imapfilter/config.lua";
in {
  systemd.user.services.imapfilter = {
    after = [ "mbsync.service" ];
    wantedBy = [ "mbsync.service" ];
    serviceConfig.ExecStart = [''
      ${pkgs.imapfilter}/bin/imapfilter -c ${imapfilterconfig} -t /etc/ssl/certs/ca-bundle.crt -v
    ''];
    # serviceConfig.Restart = "always";
  };

  my.home.xdg.configFile = {
    "imapfilter" = {
      source = <config/imapfilter>;
      recursive = true;
    };
  };
}
