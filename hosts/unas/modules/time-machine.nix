{
  networking.firewall.allowedTCPPorts = [
    548 # netatalk
  ];

  systemd.services.netatalk.unitConfig.RequiresMountsFor = [ "/data/backup/moni/time-machine" ];
  systemd.tmpfiles.rules = [ "d /data/backup/moni/time-machine 0700 monimiller users -" ];

  services = {
    netatalk = {
      enable = true;

      settings = {
        "moni-time-machine" = {
          "time machine" = "yes";
          path = "/data/backup/moni/time-machine";
          "valid users" = "monimiller";
        };
      };
    };

    avahi = {
      enable = true;
      nssmdns4 = true;

      publish = {
        enable = true;
        userServices = true;
      };
    };
  };
}
# https://codeberg.org/totoroot/dotfiles/src/branch/main/modules/services/time-machine.nix
