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
    virtualisation.oci-containers = {
      # backend = "podman";
      containers.homeassistant = {
        volumes = ["home-assistant:/config"];
        environment.TZ = "America/Chicago";
        image = "ghcr.io/home-assistant/home-assistant:stable"; # Warning: if the tag does not change, the image will not be updated
        extraOptions = [
          "--network=host"
          "--device=/dev/ttyACM0:/dev/ttyACM0" # Example, change this to match your own hardware
        ];
      };
    };
  };
}
