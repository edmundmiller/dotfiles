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
    }
  );
}
