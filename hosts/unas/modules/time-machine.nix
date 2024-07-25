{
  networking.firewall.allowedTCPPorts = [
    548 # netatalk
  ];

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

