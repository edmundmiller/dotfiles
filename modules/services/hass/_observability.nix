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
    pingKeyFile = lib.my.mkOpt lib.types.str "";
    slug = lib.my.mkOpt (lib.types.strMatching "[a-z0-9_-]+") "ha-runtime";
    expectedWarnings = lib.my.mkOpt (lib.types.listOf lib.types.str) [ ];
  };

  config = lib.optionalAttrs (!isDarwin) (
    lib.mkIf config.modules.services.hass.enable {
      environment.systemPackages = [ healthCommand ];

      assertions = [
        {
          assertion = !cfg.enable || (cfg.tokenFile != "" && cfg.pingKeyFile != "");
          message = "HA health monitoring requires tokenFile and pingKeyFile.";
        }
      ];

      systemd.services.hass-health = lib.mkIf cfg.enable {
        description = "Inspect HA runtime health and report to Healthchecks.io";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        unitConfig.ConditionPathExists = "/var/lib/hass-health/${cfg.slug}.ready";
        serviceConfig = {
          Type = "oneshot";
          DynamicUser = true;
          LoadCredential = [
            "ha-token:${cfg.tokenFile}"
            "ping-key:${cfg.pingKeyFile}"
          ];
          TimeoutStartSec = "90s";
          TimeoutStopSec = "45s";
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
          # SERVICE_RESULT also covers timeouts and signals, unlike EXIT_STATUS.
          # Send no HA report or credentials to the external monitor.
          ExecStopPost = pkgs.writeShellScript "hass-health-ping" ''
            set -eu
            result=fail
            if [ "$SERVICE_RESULT" = success ]; then result=0; fi
            key=$(cat "$CREDENTIALS_DIRECTORY/ping-key")
            printf 'url = "https://hc-ping.com/%s/${cfg.slug}/%s"\n' "$key" "$result" \
              | ${pkgs.curl}/bin/curl --config - --fail --silent --show-error \
                  --max-time 10 --retry 2 --retry-max-time 30 > /dev/null
          '';
        };
      };

      systemd.timers.hass-health = lib.mkIf cfg.enable {
        description = "Inspect HA runtime health every two minutes";
        wantedBy = [ "timers.target" ];
        # Ordinary deployments must not arm a heartbeat before approved setup.
        unitConfig.ConditionPathExists = "/var/lib/hass-health/${cfg.slug}.ready";
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
