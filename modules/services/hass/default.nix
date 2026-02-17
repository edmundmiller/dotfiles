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
          "met"
          "radio_browser"
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

          # --- Input helpers (all from defaultIntegrations, no extraComponents needed) ---
          input_boolean = {
            guest_mode = {
              name = "Guest Mode";
              icon = "mdi:account-group";
            };
            goodnight = {
              name = "Goodnight";
              icon = "mdi:weather-night";
            };
            do_not_disturb = {
              name = "Do Not Disturb";
              icon = "mdi:minus-circle";
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

          input_number = {
            tv_sleep_timer = {
              name = "TV Sleep Timer";
              icon = "mdi:timer-outline";
              min = 0;
              max = 240;
              step = 15;
              unit_of_measurement = "min";
            };
          };

          input_datetime = {
            morning_time = {
              name = "Morning Time";
              icon = "mdi:weather-sunset-up";
              has_date = false;
              has_time = true;
            };
            bedtime = {
              name = "Bedtime";
              icon = "mdi:weather-night";
              has_date = false;
              has_time = true;
            };
          };

          timer = {
            sleep = {
              name = "Sleep Timer";
              icon = "mdi:timer-sand";
              duration = "02:00:00";
            };
          };

          counter = {
            tv_on_today = {
              name = "TV Sessions Today";
              icon = "mdi:television";
              step = 1;
            };
          };

          schedule = { };

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
        "${config.services.home-assistant.configDir}/devices.yaml" = {
          L.argument = "${./devices.yaml}";
        };
      };

      # Apply declarative device→area assignments after HA starts
      systemd.services.hass-apply-devices = {
        description = "Apply declarative device→area assignments from devices.yaml";
        wantedBy = [ "multi-user.target" ];
        after = [ "home-assistant.service" ];
        requires = [ "home-assistant.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          # Wait for HA to be fully ready (API available)
          # /api/ returns 401 when HA is up (vs connection refused when not ready)
          ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 60); do ${pkgs.curl}/bin/curl -so /dev/null -w \"%%{http_code}\" http://127.0.0.1:8123/api/ 2>/dev/null | grep -qE \"(200|401|403)\" && exit 0; sleep 2; done; echo \"HA API not ready after 120s\"; exit 1'";
          ExecStart =
            let
              py = pkgs.python3.withPackages (ps: [ ps.websockets ]);
            in
            "${py}/bin/python3 ${./apply-devices.py} ${config.services.home-assistant.configDir}/devices.yaml";
        };
      };

      # Nix-managed blueprints (symlinked into HA config dir by NixOS module)
      services.home-assistant.blueprints = {
        automation = [
          ./blueprints/automation/custom/media_idle_auto_off.yaml
          ./blueprints/automation/custom/mode_switch.yaml
          ./blueprints/automation/custom/toggle_routine.yaml
        ];
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
