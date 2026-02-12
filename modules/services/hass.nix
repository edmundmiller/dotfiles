{
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.hass;
in
{
  options.modules.services.hass = {
    enable = mkBoolOpt false;
    configDir = mkOpt types.str "${config.user.home}/HomeAssistant";
    usbDevice = mkOpt (types.nullOr types.str) null;
    port = mkOpt types.port 8123;
    homebridge = {
      enable = mkBoolOpt false;
      openFirewall = mkBoolOpt true;
      user = mkOpt types.str "homebridge";
      group = mkOpt types.str "homebridge";
      userStoragePath = mkOpt types.str "/var/lib/homebridge";
      settings = mkOpt types.attrs { };
      uiSettings = mkOpt types.attrs { };
    };
  };

  # NixOS-only service (OCI containers)
  config = optionalAttrs (!isDarwin) (
    mkIf cfg.enable {
      systemd.tmpfiles.rules = [
        "d ${cfg.configDir} 0750 ${config.user.name} users -"
      ];

      virtualisation.oci-containers.containers."homeassistant" = {
        autoStart = true;
        image = "ghcr.io/home-assistant/home-assistant:stable";
        volumes = [
          "${cfg.configDir}:/config"
          "/etc/localtime:/etc/localtime:ro"
        ];
        extraOptions = [
          "--network=host"
          "--privileged"
        ]
        ++ optionals (cfg.usbDevice != null) [ "--device=${cfg.usbDevice}" ];
      };

      networking.firewall.allowedTCPPorts = [ cfg.port ];

      services.homebridge = mkIf cfg.homebridge.enable {
        enable = true;
        openFirewall = cfg.homebridge.openFirewall;
        user = cfg.homebridge.user;
        group = cfg.homebridge.group;
        userStoragePath = cfg.homebridge.userStoragePath;
        settings = cfg.homebridge.settings;
        uiSettings = cfg.homebridge.uiSettings;
      };
    }
  );
}
