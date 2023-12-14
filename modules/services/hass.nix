{
  options,
  config,
  lib,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.services.hass;
in {
  options.modules.services.hass = {enable = mkBoolOpt false;};

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers."homeassistant" = {
      autoStart = true;
      image = "ghcr.io/home-assistant/home-assistant:stable";
      volumes = [
        "/home/emiller/HomeAssistant:/config"
        "/etc/localtime:/etc/localtime:ro"
      ];
      extraOptions = [
        "--device=/dev/ttyUSB0"
        "--network=host"
        "--privileged"
      ];
    };
  };
}
