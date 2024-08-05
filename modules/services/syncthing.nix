{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.syncthing;
in
{
  options.modules.services.syncthing = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [ syncthing ];

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
        iphone.id = "S4UUK5M-MV6EGGH-GAW7KGW-4LOHO24-4K3BOKV-7TVOAIJ-AYZY5FA-DJY7FAV"; # Set up externally
        meshify.id = "BNE2NYW-PLPCOLI-Z2T6Y5X-YICNTZO-RLFCSMN-VJ4QFPD-XJILLSQ-34XERAQ";
        nuc.id = "AUP2DGW-DVFZ5CT-D3TU2OH-SR7AO4A-WGAVWUE-Z2WWUTE-C67Z3KO-ERF4LQN";
        unas.id = "XRLWH6T-X457IBB-HM4U4E3-4CNOBGS-NBSZI4V-2WM75VE-3UM4QWJ-OTHUEQI";
      };
      overrideFolders = true;
      overrideDevices = true;
      settings.folders =
        let
          deviceEnabled = devices: lib.elem config.networking.hostName devices;
          deviceType = devices: if deviceEnabled devices then "sendreceive" else "receiveonly";
        in
        {
          archive = rec {
            devices = [
              "framework"
              "meshify"
              "nuc"
              "unas"
            ];
            path = "/home/${config.user.name}/archive";
            fsWatcherEnabled = false;
            rescanIntervalS = 3600 * 6;
            type = deviceType [
              "framework"
              "meshify"
            ];
            enable = deviceEnabled devices;
            versioning.type = "simple";
            versioning.params.keep = "2";
          };
          sync = rec {
            devices = [
              "framework"
              "iphone"
              "meshify"
              "nuc"
              "unas"
            ];
            path = "/home/${config.user.name}/sync";
            fsWatcherEnabled = true;
            rescanIntervalS = 3600 * 6;
            type = deviceType [
              "framework"
              "meshify"
              "iphone"
            ];
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
            devices = [
              "framework"
              "meshify"
              "nuc"
              "unas"
            ];
            path = "/home/${config.user.name}/src";
            fsWatcherEnabled = false;
            rescanIntervalS = 3600 * 2;
            type = deviceType [
              "framework"
              "meshify"
            ];
            enable = deviceEnabled devices;
          };
          secrets = rec {
            devices = [
              "framework"
              "iphone"
              "meshify"
              "nuc"
              "unas"
            ];
            path = "/home/${config.user.name}/.secrets";
            fsWatcherEnabled = true;
            rescanIntervalS = 3600;
            type = deviceType [
              "framework"
              "meshify"
            ];
            enable = deviceEnabled devices;
          };
        };
    };
  };
}
