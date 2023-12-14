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
    services.home-assistant = {
      enable = true;
      config = {
        http = {
          use_x_forwarded_for = true;
          trusted_proxies = ["127.0.0.1" "::1"];
        };

        homeassistant = {
          unit_system = "imperial";
          time_zone = "America/Chicago";
          temperature_unit = "C";
          name = "home";
          latitude = 32.983;
          longitude = -96.752;
        };
        http.server_port = 8123;
      };

      openFirewall = true;
    };
  };
}
