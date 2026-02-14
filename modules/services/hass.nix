{
  config,
  lib,
  pkgs,
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
    tailscaleService = {
      enable = mkBoolOpt false;
      serviceName = mkOpt types.str "homeassistant";
      httpsPort = mkOpt types.port 443;
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

      # Open Home Assistant and optional Tailscale Service HTTPS on tailscale0 only.
      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
        cfg.port
      ]
      ++ optionals cfg.tailscaleService.enable [ cfg.tailscaleService.httpsPort ];

      services.homebridge = mkIf cfg.homebridge.enable {
        enable = true;
        openFirewall = cfg.homebridge.openFirewall;
        user = cfg.homebridge.user;
        group = cfg.homebridge.group;
        userStoragePath = cfg.homebridge.userStoragePath;
        settings = cfg.homebridge.settings;
        uiSettings = cfg.homebridge.uiSettings;
      };

      # Tailscale Service proxy (HTTPS -> local Home Assistant HTTP)
      systemd.services.hass-tailscale-serve = mkIf cfg.tailscaleService.enable {
        description = "Tailscale Service proxy for Home Assistant";
        wantedBy = [ "multi-user.target" ];
        after = [
          "${config.virtualisation.oci-containers.backend}-homeassistant.service"
          "tailscaled.service"
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=${toString cfg.tailscaleService.httpsPort} http://localhost:${toString cfg.port} && exit 0; sleep 1; done; exit 1'";
          ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
        };
      };
    }
  );
}
