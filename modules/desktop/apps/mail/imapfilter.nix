{ config, lib, pkgs, ... }:

with lib;
with lib.my;
let
  imapfilterconfig = "/home/emiller/.config/imapfilter/config.lua";

  cfg = config.modules.desktop.apps.mail.imapfilter;
in {
  options.modules.desktop.apps.mail.imapfilter = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
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
  };
}
