{ config, lib, pkgs, ... }:

{
  services.borgbackup.jobs = {
    homeBackup = {
      paths = "/home";
      exclude =
        [ "/home/*/.cache" "/home/emiller/torrents" "/home/emiller/src" ];
      repo = "/data/borg";
      encryption = {
        mode = "repokey";
        passCommand = "${pkgs.pass}/bin/pass borg";
      };
      # compression = "auto,lzma";
      startAt = "weekly";
      user = "emiller";
    };
  };
}
