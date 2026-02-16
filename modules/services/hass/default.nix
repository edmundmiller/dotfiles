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

    # Extra integrations to load (no YAML config needed)
    extraComponents = mkOpt (types.listOf types.str) [ ];

    # Custom components from nixpkgs (e.g. pkgs.home-assistant-custom-components.*)
    customComponents = mkOpt (types.listOf types.package) [ ];

    # Custom lovelace modules
    customLovelaceModules = mkOpt (types.listOf types.package) [ ];

    # Matter Server for Matter/Thread device support
    matter = {
      enable = mkBoolOpt false;
    };

    # Postgres recorder backend (faster than default SQLite)
    postgres = {
      enable = mkBoolOpt false;
      database = mkOpt types.str "hass";
      user = mkOpt types.str "hass";
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

  config = optionalAttrs (!isDarwin) (
    mkIf cfg.enable {

      services.home-assistant = {
        enable = true;

        extraComponents = [
          # Required for onboarding
          "analytics"
          "google_translate"
          "met"
          "radio_browser"
          "shopping_list"
          # Fast zlib compression
          "isal"
        ]
        ++ optionals cfg.matter.enable [ "matter" ]
        ++ cfg.extraComponents;

        inherit (cfg) customComponents customLovelaceModules;

        extraPackages = ps: [ ] ++ optionals cfg.postgres.enable [ ps.psycopg2 ];

        config = {
          default_config = { };

          http = {
            server_host = [
              "::1"
              "127.0.0.1"
            ];
            trusted_proxies = [
              "::1"
              "127.0.0.1"
            ];
            use_x_forwarded_for = true;
          };

          recorder = mkIf cfg.postgres.enable {
            db_url = "postgresql://@/${cfg.postgres.database}";
          };

          # Allow UI-created automations/scenes/scripts alongside declarative ones
          "automation ui" = "!include automations.yaml";
          "scene ui" = "!include scenes.yaml";
          "script ui" = "!include scripts.yaml";
        };
      };

      # Create empty yaml files so HA doesn't fail on first start
      systemd.tmpfiles.rules = [
        "f ${config.services.home-assistant.configDir}/automations.yaml 0644 hass hass"
        "f ${config.services.home-assistant.configDir}/scenes.yaml 0644 hass hass"
        "f ${config.services.home-assistant.configDir}/scripts.yaml 0644 hass hass"
      ];

      # Matter Server
      services.matter-server = mkIf cfg.matter.enable {
        enable = true;
      };

      # PostgreSQL recorder backend
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

      # Firewall: open HA port on tailscale0 only
      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
        config.services.home-assistant.config.http.server_port
      ];

      # Homebridge
      services.homebridge = mkIf cfg.homebridge.enable {
        enable = true;
        inherit (cfg.homebridge) openFirewall;
        inherit (cfg.homebridge) user;
        inherit (cfg.homebridge) group;
        inherit (cfg.homebridge) userStoragePath;
        inherit (cfg.homebridge) settings;
        inherit (cfg.homebridge) uiSettings;
      };

      # Tailscale Service proxy (HTTPS -> local HA)
      systemd.services.hass-tailscale-serve = mkIf cfg.tailscaleService.enable {
        description = "Tailscale Service proxy for Home Assistant";
        wantedBy = [ "multi-user.target" ];
        after = [
          "home-assistant.service"
          "tailscaled.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://localhost:${toString config.services.home-assistant.config.http.server_port} && exit 0; sleep 1; done; exit 1'";
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
