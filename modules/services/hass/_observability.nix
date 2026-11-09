# Imported explicitly by default.nix; exclude it from recursive module discovery.
{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
let
  cfg = config.modules.services.hass.healthcheck;
  readyFile = "/var/lib/hass-health/nuc-ha-runtime-gatus.ready";
  statusFile = "/run/hass-health/status.json";
  statusPort = 8124;
  healthCommand = pkgs.writeShellScriptBin "hass-health" ''
    export HASS_EXPECTED_VERSION="''${HASS_EXPECTED_VERSION-${config.services.home-assistant.package.version}}"
    export HASS_CRITICAL_ENTITIES="''${HASS_CRITICAL_ENTITIES-climate.main_floor climate.master_suite script.goodnight script.good_morning script.get_ready_for_bed}"
    exec ${pkgs.python3.withPackages (ps: [ ps.websockets ])}/bin/python3 ${./hass-health.py} "$@"
  '';
in
{
  options.modules.services.hass.healthcheck = {
    enable = lib.my.mkBoolOpt false;
    tokenFile = lib.my.mkOpt lib.types.str "";
    expectedWarnings = lib.my.mkOpt (lib.types.listOf lib.types.str) [ ];
  }
  // lib.my.mkRegistry {
    gatus = {
      name = "Home Assistant Runtime";
      group = "Smart Home";
      order = 15;
      url = "http://127.0.0.1:${toString statusPort}/health";
      interval = "60s";
      conditions = [ "[STATUS] == 200" ];
      alerts = true;
    };
  };

  config = lib.optionalAttrs (!isDarwin) (
    lib.mkIf config.modules.services.hass.enable {
      environment.systemPackages = [ healthCommand ];

      assertions = [
        {
          assertion = !cfg.enable || (cfg.tokenFile != "" && config.modules.services.gatus.enable);
          message = "HA health monitoring requires tokenFile and Gatus.";
        }
      ];

      systemd.services.hass-health = lib.mkIf cfg.enable {
        description = "Inspect HA runtime health for Gatus";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        unitConfig.ConditionPathExists = readyFile;
        serviceConfig = {
          Type = "oneshot";
          DynamicUser = true;
          LoadCredential = [ "ha-token:${cfg.tokenFile}" ];
          RuntimeDirectory = "hass-health";
          RuntimeDirectoryMode = "0755";
          RuntimeDirectoryPreserve = "yes";
          TimeoutStartSec = "90s";
          TimeoutStopSec = "10s";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          ExecStart = pkgs.writeShellScript "hass-health-check" ''
            exec ${healthCommand}/bin/hass-health health --json \
              --url http://[::1]:8123 \
              --token-file "$CREDENTIALS_DIRECTORY/ha-token" \
              ${lib.escapeShellArgs (
                lib.concatMap (warning: [
                  "--expected-warning"
                  warning
                ]) cfg.expectedWarnings
              )}
          '';
          # Capture timeout/signal failures too, without publishing HA contents.
          ExecStopPost = "${pkgs.python3}/bin/python3 ${./monitor-gatus.py} publish --status-file ${statusFile}";
        };
      };

      systemd.services.hass-health-http = lib.mkIf cfg.enable {
        description = "Serve freshness-aware HA status to local Gatus";
        wantedBy = [ "multi-user.target" ];
        unitConfig.ConditionPathExists = readyFile;
        serviceConfig = {
          DynamicUser = true;
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          ExecStart = "${pkgs.python3}/bin/python3 ${./monitor-gatus.py} serve --status-file ${statusFile} --port ${toString statusPort}";
        };
      };

      systemd.timers.hass-health = lib.mkIf cfg.enable {
        description = "Inspect HA runtime health every two minutes";
        wantedBy = [ "timers.target" ];
        # Ordinary deployments must not arm the monitor before approved setup.
        unitConfig.ConditionPathExists = readyFile;
        timerConfig = {
          # Let integrations finish their startup retries after a host boot.
          OnBootSec = "12min";
          OnUnitActiveSec = "2min";
          RandomizedDelaySec = "10s";
          AccuracySec = "10s";
        };
      };

      services.home-assistant.config.script =
        lib.genAttrs
          [
            "get_ready_for_bed"
            "goodnight"
            "good_morning"
            "apply_climate_policy"
            "apply_ecobee_profile"
            "apply_ecobee_target"
          ]
          (_: {
            trace.stored_traces = 20;
          });
    }
  );
}
