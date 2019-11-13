{ config, lib, pkgs, ... }:

{
  services.borgbackup.jobs = {
    homeBackup = {
      paths = "/home/emiller";
      exclude = [ "/home/*/.cache" ];
      repo = "/data/emiller/borg";
      encryption = {
        mode = "repokey";
        passCommand = "pass borg";
      };
      # compression = "auto,lzma";
      startAt = "weekly";
    };
  };
}
