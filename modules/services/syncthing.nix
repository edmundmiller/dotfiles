{ config, lib, pkgs, ... }:

{
  my.packages = with pkgs; [ syncthing ];

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    user = config.my.username;
    configDir = "/home/${config.my.username}/.config/syncthing";
    dataDir = "/home/${config.my.username}/.local/share/syncthing";
    declarative = {
      devices = {
        omen.id =
          "JZCOYRI-OVUFHZ5-TV3WQ7D-L7PV3JA-6JDYG6D-TOJ47KK-EJMX4TR-XQAL4AY";
        oneplus.id =
          "6EYD6V4-4KPXAVK-PR3GGLT-AYIWQ72-BUWQAUJ-PA7KAH7-QVGXA7Q-SKSL7AD";
        meshify.id =
          "BNE2NYW-PLPCOLI-Z2T6Y5X-YICNTZO-RLFCSMN-VJ4QFPD-XJILLSQ-34XERAQ";
        node.id =
          "OBXUZUC-NOTB65C-POT2MAD-MDCOEIB-HIPGRIZ-LVNRJO6-HF25SOF-URFN3QP";
        # envy.id =
        # TODO
      };
      folders = let
        deviceEnabled = devices: lib.elem config.networking.hostName devices;
        deviceType = devices:
          if deviceEnabled devices then "sendreceive" else "receiveonly";
      in {
        sync = rec {
          devices = [ "omen" "oneplus" "meshify" "node" ];
          path = "/home/${config.my.username}/sync";
          watch = false;
          rescanInterval = 3600 * 2;
          type = deviceType [ "omen" "meshify" ];
          enable = deviceEnabled devices;
        };
        secrets = rec {
          devices = [ "omen" "oneplus" "meshify" "node" ];
          path = "/home/${config.my.username}/.secrets";
          watch = true;
          rescanInterval = 3600;
          type = deviceType [ "omen" "meshify" ];
          enable = deviceEnabled devices;
        };
      };
    };
  };

  my.user.extraGroups = [ "syncthing" ];
}
