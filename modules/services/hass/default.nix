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
    image = mkOpt types.str "ghcr.io/home-assistant/home-assistant:stable";

    # Location/environment (parallels home-ops ExternalSecret: HASS_ELEVATION, HASS_LATITUDE, HASS_LONGITUDE)
    timezone = mkOpt types.str "America/Chicago";
    latitude = mkOpt (types.nullOr types.str) null;
    longitude = mkOpt (types.nullOr types.str) null;
    elevation = mkOpt (types.nullOr types.str) null;

    # Postgres (parallels home-ops: POSTGRES_HOST, INIT_POSTGRES_DBNAME, INIT_POSTGRES_HOST, etc.)
    postgres = {
      enable = mkBoolOpt false;
      host = mkOpt types.str "localhost";
      port = mkOpt types.port 5432;
      database = mkOpt types.str "home_assistant";
      user = mkOpt types.str "home_assistant";
      # Password should come from a secret/env file, not nix store
      passwordFile = mkOpt (types.nullOr types.path) null;
    };

    # Code-server sidecar (parallels home-ops patches/addons.yaml)
    codeServer = {
      enable = mkBoolOpt false;
      image = mkOpt types.str "ghcr.io/coder/code-server:latest";
      port = mkOpt types.port 8443;
    };

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
    };
    homebridge.tailscaleService = {
      enable = mkBoolOpt false;
      serviceName = mkOpt types.str "homebridge";
      port = mkOpt types.port 8581;
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
        image = cfg.image;
        volumes = [
          "${cfg.configDir}:/config"
          "/etc/localtime:/etc/localtime:ro"
        ];
        environment = {
          TZ = cfg.timezone;
        }
        // optionalAttrs (cfg.latitude != null) {
          HASS_LATITUDE = cfg.latitude;
        }
        // optionalAttrs (cfg.longitude != null) {
          HASS_LONGITUDE = cfg.longitude;
        }
        // optionalAttrs (cfg.elevation != null) {
          HASS_ELEVATION = cfg.elevation;
        }
        // optionalAttrs cfg.postgres.enable {
          POSTGRES_HOST = cfg.postgres.host;
          POSTGRES_DB = cfg.postgres.database;
        };
        extraOptions = [
          "--network=host"
          "--privileged"
        ]
        ++ optionals (cfg.usbDevice != null) [ "--device=${cfg.usbDevice}" ];
      };

      # Code-server sidecar for editing config (mirrors home-ops addons patch)
      virtualisation.oci-containers.containers."hass-code-server" = mkIf cfg.codeServer.enable {
        autoStart = true;
        image = cfg.codeServer.image;
        volumes = [
          "${cfg.configDir}:/config"
        ];
        ports = [ "${toString cfg.codeServer.port}:8080" ];
        environment = {
          HASS_SERVER = "http://localhost:${toString cfg.port}";
        };
        extraOptions = [ "--network=host" ];
      };

      # Postgres for recorder (mirrors home-ops postgres-init initContainer)
      services.postgresql = mkIf cfg.postgres.enable {
        enable = true;
        ensureDatabases = [ cfg.postgres.database ];
        ensureUsers = [
          {
            name = cfg.postgres.user;
            ensureDBOwnership = true;
          }
        ];
      };

      # Open Home Assistant port on tailscale0 only
      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
        cfg.port
      ]
      ++ optionals cfg.codeServer.enable [ cfg.codeServer.port ];

      services.homebridge = mkIf cfg.homebridge.enable {
        enable = true;
        inherit (cfg.homebridge) openFirewall;
        inherit (cfg.homebridge) user;
        inherit (cfg.homebridge) group;
        inherit (cfg.homebridge) userStoragePath;
        inherit (cfg.homebridge) settings;
        inherit (cfg.homebridge) uiSettings;
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
          ExecStart = "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://localhost:${toString cfg.port} && exit 0; sleep 1; done; exit 1'";
          ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
        };
      };

      # Tailscale Service proxy for Homebridge
      systemd.services.homebridge-tailscale-serve = mkIf cfg.homebridge.tailscaleService.enable {
        description = "Tailscale Service proxy for Homebridge";
        wantedBy = [ "multi-user.target" ];
        after = [
          "homebridge.service"
          "tailscaled.service"
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.homebridge.tailscaleService.serviceName} --https=443 http://localhost:${toString cfg.homebridge.tailscaleService.port} && exit 0; sleep 1; done; exit 1'";
          ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.homebridge.tailscaleService.serviceName} || true'";
        };
      };
    }
  );
}
