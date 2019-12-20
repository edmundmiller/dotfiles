{ config, lib, pkgs, ... }:

{
  users.users.emiller.extraGroups = [ "syncthing" ];

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
          "5D6ELCY-YK2GOPP-BNJLVOH-F4OGXUD-D3Z5RCQ-LVGIFSS-MLS6LV5-DYLNYAK";
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
        envy = {
          id = "FIXME";
          name = "envy";
        };
      };
      folders = {
        sync = {
          devices = [ "omen" "oneplus" "meshify" "envy" ];
          id = "sync";
          path = "/home/emiller/sync";
        };
      };
    };
  };
}
