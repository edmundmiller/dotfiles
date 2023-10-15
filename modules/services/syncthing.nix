{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.services.syncthing;
in {
  options.modules.services.syncthing = {enable = mkBoolOpt false;};

  config = mkIf cfg.enable {
    user.packages = with pkgs; [syncthing];

    services.syncthing = {
      enable = true;
      openDefaultPorts = true;
      user = config.user.name;
      group = "users";
      package = pkgs.syncthing;
      configDir = "/home/${config.user.name}/.config/syncthing";
      dataDir = "/home/${config.user.name}/.local/share/syncthing";
      settings.devices = {
        framework.id = "CHWKD4E-A7MZXUT-EGANUVC-YJDNMDN-6WLTMYQ-TLI2RVC-PYBCNAX-UA3LFAC";
        pixel.id = "UV3UWHG-GCKHIFV-6ORBZSE-Z3IP2CN-NO2FBYE-6BDIAPC-6FJZ4AO-BGH5LQZ"; # Set up externally
        meshify.id = "BNE2NYW-PLPCOLI-Z2T6Y5X-YICNTZO-RLFCSMN-VJ4QFPD-XJILLSQ-34XERAQ";
        pbp.id = "PQNQ54X-4WQ32AV-2TWQI4N-KF64EKW-FRFEVAL-WCONWOY-V4BK4PB-JYQGZQO"; # Set up externally
        unas.id = "QRDMQKL-RX4PO5I-2VM3SBA-42G3PVX-ZGGRDYU-P3C3AFN-OKLOVK4-BXRJAAN";
      };
      settings.folders = let
        deviceEnabled = devices: lib.elem config.networking.hostName devices;
        deviceType = devices:
          if deviceEnabled devices
          then "sendreceive"
          else "receiveonly";
      in {
        archive = rec {
          devices = ["framework" "meshify" "unas"];
          path = "/home/${config.user.name}/archive";
          fsWatcherEnabled = false;
          rescanIntervalS = 3600 * 6;
          type = deviceType ["framework" "meshify"];
          enable = deviceEnabled devices;
          versioning.type = "simple";
          versioning.params.keep = "2";
        };
        elfeed = rec {
          devices = ["framework" "meshify" "unas" "pbp"];
          path = "/home/${config.user.name}/.config/emacs/.local/elfeed";
          fsWatcherEnabled = false;
          rescanIntervalS = 3600 * 6;
          type = deviceType ["framework" "meshify" "pbp"];
          enable = deviceEnabled devices;
        };
        sync = rec {
          devices = ["framework" "pixel" "meshify" "unas" "pbp"];
          path = "/home/${config.user.name}/sync";
          fsWatcherEnabled = true;
          rescanIntervalS = 3600 * 6;
          type = deviceType ["framework" "meshify" "pixel"];
          enable = deviceEnabled devices;
          versioning = {
            type = "staggered";
            params = {
              cleanInterval = "3600";
              maxAge = "15768000";
            };
          };
        };
        src = rec {
          devices = ["framework" "meshify" "unas" "pbp"];
          path = "/home/${config.user.name}/src";
          fsWatcherEnabled = false;
          rescanIntervalS = 3600 * 2;
          type = deviceType ["framework" "meshify"];
          enable = deviceEnabled devices;
        };
        secrets = rec {
          devices = ["framework" "pixel" "meshify" "unas" "pbp"];
          path = "/home/${config.user.name}/.secrets";
          fsWatcherEnabled = true;
          rescanIntervalS = 3600;
          type = deviceType ["framework" "meshify" "pbp"];
          enable = deviceEnabled devices;
        };
        seedvault = rec {
          devices = ["pixel" "unas" "meshify"];
          path = "/home/${config.user.name}/.seedvault";
          fsWatcherEnabled = false;
          rescanIntervalS = 3600;
          type = deviceType ["pixel"];
          enable = deviceEnabled devices;
        };
      };
    };
  };
}
