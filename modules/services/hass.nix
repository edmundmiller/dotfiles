{
  options,
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.hass;
  homeDir = config.users.users.${config.user.name}.home;
in
{
  options.modules.services.hass = {
    enable = mkBoolOpt false;
  };

  # NixOS-only service (OCI containers)
  config = mkIf cfg.enable (optionalAttrs (!isDarwin) {
    virtualisation.oci-containers.containers."homeassistant" = {
      autoStart = true;
      image = "ghcr.io/home-assistant/home-assistant:stable";
      volumes = [
        "${homeDir}/HomeAssistant:/config"
        "/etc/localtime:/etc/localtime:ro"
      ];
      extraOptions = [
        "--device=/dev/ttyUSB0"
        "--network=host"
        "--privileged"
      ];
    };

    networking.firewall.allowedTCPPorts = [ 8123 ];
  });
}
