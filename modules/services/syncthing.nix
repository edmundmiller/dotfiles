{ config, options, pkgs, lib, ... }:
with lib; {
  options.modules.services.syncthing = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.modules.services.syncthing.enable {
    my.packages = with pkgs; [ unstable.syncthing ];

    services.syncthing = {
      enable = true;
      openDefaultPorts = true;
      user = config.my.username;
      group = "users";
      package = pkgs.unstable.syncthing;
      configDir = "/home/${config.my.username}/.config/syncthing";
      dataDir = "/home/${config.my.username}/.local/share/syncthing";
      declarative = {
        devices = {
          omen.id =
            "JCHJHFI-DSCKEDQ-THTQ4BE-GA42KPH-LOTPD6M-GEXXLME-JJHW6GD-PRYRNAZ";
          oneplus.id =
            "6EYD6V4-4KPXAVK-PR3GGLT-AYIWQ72-BUWQAUJ-PA7KAH7-QVGXA7Q-SKSL7AD";
          meshify.id =
            "BNE2NYW-PLPCOLI-Z2T6Y5X-YICNTZO-RLFCSMN-VJ4QFPD-XJILLSQ-34XERAQ";
          vultr.id =
            "DOAM5XZ-GXLXUN6-YIFJW33-PTEHNPQ-OZNQJFP-7ISSOIN-HZ5GNUR-KTT5JQJ";
          rock.id =
            "PGYQ6SB-T7NHUZ7-KSS6VTS-FJSP7WY-WZVQYJV-LHTCCIQ-CBINZA6-3BLUOQV";
          pbp.id =
            "CRC7IPG-AENABLD-L5MVEUV-KOVM7ZQ-MASB2SB-VSTKS7O-OYFNQCK-D3GTCAA";
          pi.id =
            "LS2UAFQ-MIFBIPJ-CNNPTJC-PSN7K4Z-67I5F66-3IJDQYT-MQN446A-TSPGDQB";
        };
        folders = let
          deviceEnabled = devices: lib.elem config.networking.hostName devices;
          deviceType = devices:
            if deviceEnabled devices then "sendreceive" else "receiveonly";
        in {
          archive = rec {
            devices = [ "meshify" "omen" "vultr" ];
            path = "/home/${config.my.username}/archive";
            watch = false;
            rescanInterval = 3600 * 6;
            type = deviceType [ "meshify" ];
            enable = deviceEnabled devices;
          };
          elfeed = rec {
            devices = [ "meshify" "omen" "vultr" ];
            path = "/home/${config.my.username}/.config/emacs/.local/elfeed";
            watch = false;
            rescanInterval = 3600 * 6;
            type = deviceType [ "meshify" "omen" ];
            enable = deviceEnabled devices;
          };
          sync = rec {
            devices = [ "omen" "oneplus" "meshify" "vultr" "rock" "pbp" "pi" ];
            path = "/home/${config.my.username}/sync";
            watch = true;
            rescanInterval = 3600 * 6;
            type = deviceType [ "meshify" "omen" "pbp" ];
            enable = deviceEnabled devices;
          };
          src = rec {
            devices = [ "omen" "meshify" "vultr" "rock" "pi" ];
            path = "/home/${config.my.username}/src";
            watch = false;
            rescanInterval = 3600 * 2;
            type = deviceType [ "meshify" "omen" ];
            enable = deviceEnabled devices;
          };
          secrets = rec {
            devices = [ "omen" "oneplus" "meshify" "vultr" "rock" "pbp" ];
            path = "/home/${config.my.username}/.secrets";
            watch = true;
            rescanInterval = 3600;
            type = deviceType [ "meshify" "omen" ];
            enable = deviceEnabled devices;
          };
        };
      };
    };
  };
}
