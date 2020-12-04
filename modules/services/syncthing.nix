{ options, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.services.syncthing;
in {
  options.modules.services.syncthing = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [ syncthing ];

    services.syncthing = {
      enable = true;
      openDefaultPorts = true;
      user = config.user.name;
      group = "users";
      package = pkgs.unstable.syncthing;
      configDir = "/home/${config.user.name}/.config/syncthing";
      dataDir = "/home/${config.user.name}/.local/share/syncthing";
      declarative = {
        devices = {
          omen.id =
            "HJV4PMT-ROCGMFH-HXINT57-CKTYJSK-7QE7DH2-CEAYVJ6-NIMMDKA-MEOVNAB";
          oneplus.id =
            "UVAV55V-PAYJHDA-RDLKIGA-PTIKJAZ-7BWJHDW-TMKLGX7-RPYNTFR-LRNKKQC";
          meshify.id =
            "BNE2NYW-PLPCOLI-Z2T6Y5X-YICNTZO-RLFCSMN-VJ4QFPD-XJILLSQ-34XERAQ";
          vultr.id =
            "54HA52Z-BPYZHKF-IQAQ2TW-RJLCDW7-S3FNTIM-X3ZWM6A-AVSNVVO-XATCEQL";
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
            path = "/home/${config.user.name}/archive";
            watch = false;
            rescanInterval = 3600 * 6;
            type = deviceType [ "meshify" ];
            enable = deviceEnabled devices;
          };
          elfeed = rec {
            devices = [ "meshify" "omen" "vultr" ];
            path = "/home/${config.user.name}/.config/emacs/.local/elfeed";
            watch = false;
            rescanInterval = 3600 * 6;
            type = deviceType [ "meshify" "omen" ];
            enable = deviceEnabled devices;
          };
          sync = rec {
            devices = [ "omen" "oneplus" "meshify" "vultr" "pbp" "pi" ];
            path = "/home/${config.user.name}/sync";
            watch = true;
            rescanInterval = 3600 * 6;
            type = deviceType [ "meshify" "omen" "pbp" ];
            enable = deviceEnabled devices;
          };
          src = rec {
            devices = [ "omen" "meshify" "vultr" "pi" ];
            path = "/home/${config.user.name}/src";
            watch = false;
            rescanInterval = 3600 * 2;
            type = deviceType [ "meshify" "omen" ];
            enable = deviceEnabled devices;
          };
          secrets = rec {
            devices = [ "omen" "oneplus" "meshify" "vultr" "pbp" ];
            path = "/home/${config.user.name}/.secrets";
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
