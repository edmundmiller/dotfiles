{ config, lib, pkgs, ... }:

{
  users.users.emiller.extraGroups = [ "syncthing" ];

  environment = { systemPackages = with pkgs; [ syncthing ]; };
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    user = "emiller";
    configDir = "/home/emiller/.config/syncthing";
    dataDir = "/home/emiller/sync";
    declarative = {
      devices = {
        omen = {
          id =
            "JZCOYRI-OVUFHZ5-TV3WQ7D-L7PV3JA-6JDYG6D-TOJ47KK-EJMX4TR-XQAL4AY";
          name = "omen";
        };
        oneplus = {
          id =
            "6EYD6V4-4KPXAVK-PR3GGLT-AYIWQ72-BUWQAUJ-PA7KAH7-QVGXA7Q-SKSL7AD";
          name = "oneplus";
        };
        meshify = {
          id =
            "BNE2NYW-PLPCOLI-Z2T6Y5X-YICNTZO-RLFCSMN-VJ4QFPD-XJILLSQ-34XERAQ";
          name = "meshify";
        };
        node = {
          id =
            "KG2TTB4-47HTL4N-AGBG6W2-FBBBMKS-IKMECOJ-NEF5J6U-UNZUA24-ALBIAQ2";
          name = "node";
        };
        # envy = {
        #   id = "FIXME";
        #   name = "envy";
        # };
      };
      folders = {
        sync = {
          devices = [ "omen" "oneplus" "meshify" "node" ];
          id = "sync";
          path = "/home/emiller/sync";
        };
      };
    };
  };
}
