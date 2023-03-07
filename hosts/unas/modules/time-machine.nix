{
  networking.firewall.allowedTCPPorts = [
    548 # netatalk
  ];

  services = {
    netatalk = {
      enable = true;

      volumes = {
        "moni-time-machine" = {
          "time machine" = "yes";
          path = "/data/backup/moni/time-machine";
          "valid users" = "monimiller";
        };
      };
    };

    avahi = {
      enable = true;
      nssmdns = true;

      publish = {
        enable = true;
        userServices = true;
      };
    };
  };
}
