{ config, lib, pkgs, ... }:

with lib.my;
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

  home.configFile = {
    "imapfilter" = {
      source = "${configDir}/imapfilter";
      recursive = true;
    };
  };
}
