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

  # HACS - Home Assistant Community Store
  # https://github.com/hacs/integration
  hacs = pkgs.buildHomeAssistantComponent {
    owner = "hacs";
    domain = "hacs";
    version = "2.0.5";
    src = pkgs.fetchFromGitHub {
      owner = "hacs";
      repo = "integration";
      tag = "2.0.5";
      hash = "sha256-xj+H75A6iwyGzMvYUjx61aGiH5DK/qYLC6clZ4cGDac=";
    };
    dependencies = [ pkgs.python3Packages.aiogithubapi ];
  };
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

        customComponents = [ hacs ] ++ cfg.customComponents;
        inherit (cfg) customLovelaceModules;

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

          # --- Input helpers ---
          input_boolean = {
            guest_mode = {
              name = "Guest Mode";
              icon = "mdi:account-group";
            };
            goodnight = {
              name = "Goodnight";
              icon = "mdi:weather-night";
            };
          };

          input_select = {
            house_mode = {
              name = "House Mode";
              options = [
                "Home"
                "Away"
                "Night"
                "Movie"
              ];
              initial = "Home";
              icon = "mdi:home";
            };
          };

          # --- Automations (Nix-declared) ---
          automation = "!include automations_nix.yaml";

          # --- Scenes ---
          scene = [
            {
              name = "Movie";
              icon = "mdi:movie-open";
              entities = {
                "input_select.house_mode" = "Movie";
                "media_player.tv" = "on";
              };
            }
            {
              name = "Goodnight";
              icon = "mdi:weather-night";
              entities = {
                "input_boolean.goodnight" = "on";
                "input_select.house_mode" = "Night";
                "media_player.tv" = "off";
              };
            }
            {
              name = "Good Morning";
              icon = "mdi:weather-sunny";
              entities = {
                "input_boolean.goodnight" = "off";
                "input_select.house_mode" = "Home";
              };
            }
          ];

          # --- Scripts ---
          script = {
            tv_on = {
              alias = "Turn on TV";
              icon = "mdi:television";
              sequence = [
                {
                  action = "media_player.turn_on";
                  target.entity_id = "media_player.tv";
                }
              ];
            };
            tv_off = {
              alias = "Turn off TV";
              icon = "mdi:television-off";
              sequence = [
                {
                  action = "media_player.turn_off";
                  target.entity_id = "media_player.tv";
                }
              ];
            };
            everything_off = {
              alias = "Everything Off";
              icon = "mdi:power";
              sequence = [
                {
                  action = "media_player.turn_off";
                  target.entity_id = "media_player.tv";
                }
                {
                  action = "input_boolean.turn_on";
                  target.entity_id = "input_boolean.goodnight";
                }
                {
                  action = "input_select.select_option";
                  target.entity_id = "input_select.house_mode";
                  data.option = "Night";
                }
              ];
            };
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

      # Symlink Nix-managed YAML files into HA config dir
      systemd.tmpfiles.settings."10-hass-nix-yaml" = {
        "${config.services.home-assistant.configDir}/automations_nix.yaml" = {
          L.argument = "${./automations_nix.yaml}";
        };
      };

      # Symlink Nix-managed blueprints into HA config dir
      systemd.tmpfiles.settings."10-hass-blueprints" = {
        "${config.services.home-assistant.configDir}/blueprints/automation/custom" = {
          L.argument = "${./blueprints/automation/custom}";
        };
      };

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
