# Dagster OSS — data orchestration platform
#
# Architecture: 3 long-running services + postgres
#   - dagster-webserver (UI + GraphQL, port 3000)
#   - dagster-daemon (schedules, sensors, run queue)
#   - code location servers (gRPC, one per code location)
#
# All services share DAGSTER_HOME containing dagster.yaml + workspace.yaml.
# Postgres stores runs, events, and schedule state.
#
# Docs: https://docs.dagster.io/deployment/oss/oss-deployment-architecture
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
  cfg = config.modules.services.dagster;

  # Service names for managed code location gRPC servers
  codeServiceNames = map (loc: "dagster-code-${loc.name}.service")
    (filter (loc: loc.service.enable) cfg.codeLocations);

  # Build dagster.yaml from structured options
  dagsterYaml = pkgs.writeText "dagster-template.yaml" (builtins.toJSON (
    {
      # Storage — postgres via peer auth (no password needed)
      storage = {
        postgres = {
          postgres_db = {
            username = cfg.postgres.user;
            hostname = "localhost";
            db_name = cfg.postgres.database;
            port = 5432;
          };
        };
      };

      # Run launcher
      run_launcher =
        if cfg.runLauncher == "default" then {
          module = "dagster.core.launcher";
          class = "DefaultRunLauncher";
        } else if cfg.runLauncher == "docker" then {
          module = "dagster_docker";
          class = "DockerRunLauncher";
        } else {
          module = "dagster.core.launcher";
          class = "DefaultRunLauncher";
        };

      # Run coordinator
      run_coordinator =
        if cfg.runCoordinator == "queued" then {
          module = "dagster.core.run_coordinator";
          class = "QueuedRunCoordinator";
          config = {
            max_concurrent_runs = cfg.maxConcurrentRuns;
          };
        } else {
          module = "dagster.core.run_coordinator";
          class = "DefaultRunCoordinator";
        };

      telemetry.enabled = false;
    }
    // optionalAttrs (cfg.retentionDays > 0) {
      retention = {
        schedule.purge_after_days.skipped = cfg.retentionDays;
        sensor.purge_after_days.skipped = cfg.retentionDays;
      };
    }
    // optionalAttrs cfg.runMonitoring.enable {
      run_monitoring = {
        enabled = true;
        poll_interval_seconds = cfg.runMonitoring.pollInterval;
        max_resume_run_attempts = cfg.runMonitoring.maxResumeAttempts;
      };
    }
    // optionalAttrs (cfg.runRetries.maxRetries > 0) {
      run_retries = {
        max_retries = cfg.runRetries.maxRetries;
        retry_on_asset_or_op_failure = cfg.runRetries.retryOnFailure;
      };
    }
  ));

  # Build workspace.yaml from code locations
  workspaceYaml = pkgs.writeText "workspace.yaml" (builtins.toJSON {
    load_from = map (loc:
      if loc.type == "grpc" then {
        grpc_server = {
          host = loc.host;
          port = loc.port;
        };
      } else if loc.type == "module" then {
        python_module = loc.module;
      } else {
        python_file = loc.file;
      }
    ) cfg.codeLocations;
  });

in
{
  options.modules.services.dagster = {
    enable = mkBoolOpt false;

    # Python environment with dagster + deps (from packages/dagster.nix)
    package = mkOpt types.package pkgs.my.dagster;

    webserver = {
      port = mkOpt types.port 3000;
      host = mkOpt types.str "127.0.0.1";
    };

    postgres = {
      enable = mkBoolOpt true;
      database = mkOpt types.str "dagster";
      user = mkOpt types.str "dagster";
    };

    # Run launcher: "default" (in-process) or "docker"
    runLauncher = mkOpt types.str "default";

    # Run coordinator: "default" (immediate) or "queued" (daemon dequeues)
    runCoordinator = mkOpt types.str "queued";
    maxConcurrentRuns = mkOpt types.int 10;

    retentionDays = mkOpt types.int 7;

    runMonitoring = {
      enable = mkBoolOpt false;
      pollInterval = mkOpt types.int 120;
      maxResumeAttempts = mkOpt types.int 0;
    };

    runRetries = {
      maxRetries = mkOpt types.int 0;
      retryOnFailure = mkBoolOpt true;
    };

    # Code locations — each gets a gRPC server or points to a module/file
    # type: "grpc" | "module" | "file"
    # gRPC locations with service.enable get a managed systemd service
    codeLocations = mkOpt (types.listOf (types.submodule {
      options = {
        type = mkOpt types.str "grpc";
        # grpc options
        host = mkOpt types.str "localhost";
        port = mkOpt types.port 4000;
        # module/file options
        module = mkOpt types.str "";
        file = mkOpt types.str "";
        # Managed gRPC code server (optional — creates a systemd service)
        name = mkOpt types.str "";
        service = {
          enable = mkBoolOpt false;
          execStart = mkOpt (types.either types.str types.path) "";
          workingDirectory = mkOpt types.str "";
          environment = mkOpt (types.attrsOf types.str) {};
          environmentFiles = mkOpt (types.listOf types.str) [];
          # Extra ReadWritePaths for the service
          readWritePaths = mkOpt (types.listOf types.str) [];
        };
      };
    })) [];

    # Dagster home directory
    home = mkOpt types.str "/var/lib/dagster";

    # Extra dagster.yaml content merged into generated config
    extraConfig = mkOpt types.attrs {};

    tailscaleService = {
      enable = mkBoolOpt false;
      serviceName = mkOpt types.str "dagster";
    };

    healthcheck = {
      enable = mkBoolOpt false;
      pingUrl = mkOpt types.str "";
      interval = mkOpt types.str "2min";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (optionalAttrs (!isDarwin) {

      # Postgres database
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

      # System user
      users.users.dagster = {
        isSystemUser = true;
        group = "dagster";
        home = cfg.home;
        createHome = true;
      };
      users.groups.dagster = {};

      # DAGSTER_HOME directory with config files
      systemd.tmpfiles.rules = [
        "d ${cfg.home} 0750 dagster dagster -"
      ];

      # Prepare config — copy templates to DAGSTER_HOME
      systemd.services.dagster-config = {
        description = "Dagster config setup";
        wantedBy = [ "multi-user.target" ];
        before = [ "dagster-webserver.service" "dagster-daemon.service" ];
        after = [ "postgresql.service" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "dagster";
          Group = "dagster";
          ExecStart = pkgs.writeShellScript "dagster-setup-config" ''
            cp ${dagsterYaml} ${cfg.home}/dagster.yaml
            cp ${workspaceYaml} ${cfg.home}/workspace.yaml
            chmod 640 ${cfg.home}/dagster.yaml ${cfg.home}/workspace.yaml
          '';
        };
      };

      # Webserver — serves UI + GraphQL
      systemd.services.dagster-webserver = {
        description = "Dagster webserver";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network.target"
          "postgresql.service"
          "dagster-config.service"
        ] ++ codeServiceNames;
        requires = [ "dagster-config.service" ];

        environment.DAGSTER_HOME = cfg.home;

        serviceConfig = {
          Type = "simple";
          User = "dagster";
          Group = "dagster";
          ExecStart = "${cfg.package}/bin/dagster-webserver -h ${cfg.webserver.host} -p ${toString cfg.webserver.port} -w ${cfg.home}/workspace.yaml";
          Restart = "on-failure";
          RestartSec = 5;

          # Hardening
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [ cfg.home "/tmp" ];
          PrivateTmp = true;
        };
      };

      # Daemon — schedules, sensors, run queue
      systemd.services.dagster-daemon = {
        description = "Dagster daemon";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network.target"
          "postgresql.service"
          "dagster-config.service"
        ] ++ codeServiceNames;
        requires = [ "dagster-config.service" ];

        environment.DAGSTER_HOME = cfg.home;

        serviceConfig = {
          Type = "simple";
          User = "dagster";
          Group = "dagster";
          ExecStart = "${cfg.package}/bin/dagster-daemon run";
          Restart = "on-failure";
          RestartSec = 5;

          # Hardening
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [ cfg.home "/tmp" ];
          PrivateTmp = true;
        };
      };

      # Firewall — webserver port on tailscale
      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cfg.webserver.port ];

      # Tailscale service proxy
      systemd.services.dagster-tailscale-serve = mkIf cfg.tailscaleService.enable {
        description = "Tailscale Service proxy for Dagster";
        wantedBy = [ "multi-user.target" ];
        after = [
          "dagster-webserver.service"
          "tailscaled.service"
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://localhost:${toString cfg.webserver.port} && exit 0; sleep 1; done; exit 1'";
          ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
        };
      };

      # Healthcheck timer
      systemd.services.dagster-healthcheck-ping = mkIf cfg.healthcheck.enable {
        description = "Check Dagster health and ping healthchecks.io";
        after = [ "dagster-webserver.service" ];
        serviceConfig = {
          Type = "oneshot";
          DynamicUser = true;
          ExecStartPre = "-${pkgs.curl}/bin/curl -sS -m 10 --retry 5 ${cfg.healthcheck.pingUrl}/start";
          ExecStart = "${pkgs.curl}/bin/curl -fsS -m 10 http://localhost:${toString cfg.webserver.port}/dagit_info";
          ExecStopPost = "${pkgs.curl}/bin/curl -sS -m 10 --retry 5 ${cfg.healthcheck.pingUrl}/\${EXIT_STATUS}";
        };
      };

      systemd.timers.dagster-healthcheck-ping = mkIf cfg.healthcheck.enable {
        description = "Ping healthchecks.io on schedule";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "1min";
          OnUnitActiveSec = cfg.healthcheck.interval;
          RandomizedDelaySec = "10s";
        };
      };
    })
    # Code location gRPC services — one per codeLocation with service.enable
    (optionalAttrs (!isDarwin) {
      systemd.services = builtins.listToAttrs (
        map (loc: {
          name = "dagster-code-${loc.name}";
          value = {
            description = "Dagster code server: ${loc.name}";
            wantedBy = [ "multi-user.target" ];
            after = [
              "network.target"
              "postgresql.service"
              "dagster-config.service"
            ];
            requires = [ "dagster-config.service" ];

            environment = {
              DAGSTER_HOME = cfg.home;
            } // loc.service.environment;

            serviceConfig = {
              Type = "simple";
              User = "dagster";
              Group = "dagster";
              ExecStart = loc.service.execStart;
              Restart = "on-failure";
              RestartSec = 10;

              # Hardening
              NoNewPrivileges = true;
              ProtectSystem = "strict";
              ProtectHome = "read-only";
              ReadWritePaths = [ cfg.home "/tmp" ] ++ loc.service.readWritePaths;
              PrivateTmp = true;
            } // optionalAttrs (loc.service.workingDirectory != "") {
              WorkingDirectory = loc.service.workingDirectory;
            } // optionalAttrs (loc.service.environmentFiles != []) {
              EnvironmentFile = loc.service.environmentFiles;
            };
          };
        }) (filter (loc: loc.service.enable) cfg.codeLocations)
      );
    })
  ]);
}
