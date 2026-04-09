# Finances Dagster deployment on NUC.
#
# Runs finances_dagster.definitions as a Dagster gRPC code location under the
# shared Dagster webserver/daemon stack. Dagster schedules/sensors handle timing
# (no separate systemd timer required).
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
  cfg = config.modules.services.finances-dagster;
  dagsterCfg = config.modules.services.dagster;

  opEnvFile = "/run/finances-dagster-op.env";

  setupScript = pkgs.writeShellScript "finances-dagster-setup" ''
    set -euo pipefail

    REPO_DIR=${escapeShellArg cfg.repoPath}

    mkdir -p "$(dirname "$REPO_DIR")"
    export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=accept-new"

    if [ ! -d "$REPO_DIR/.git" ]; then
      ${pkgs.git}/bin/git clone --branch ${escapeShellArg cfg.gitBranch} --single-branch ${escapeShellArg cfg.gitUrl} "$REPO_DIR"
    else
      cd "$REPO_DIR"
      ${pkgs.git}/bin/git fetch origin
      ${pkgs.git}/bin/git reset --hard origin/${cfg.gitBranch}
    fi
  '';

  runtimePath = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.findutils
    pkgs.gawk
    pkgs.gnugrep
    pkgs.gnused
    pkgs.git
    pkgs.just
    pkgs.openssh
    pkgs._1password-cli
    pkgs.uv
  ];
  runtimeLibs = lib.makeLibraryPath [ pkgs.stdenv.cc.cc ];

  codeServerScript = pkgs.writeShellScript "finances-dagster-code-server" ''
    set -euo pipefail

    export PATH=${runtimePath}:/run/current-system/sw/bin
    export LD_LIBRARY_PATH=${runtimeLibs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

    cd ${escapeShellArg cfg.repoPath}

    # Sync lockfile-pinned deps. This repo isn't packaged, so uv may skip
    # project entry points. Install Dagster explicitly into the synced venv.
    ${pkgs.uv}/bin/uv sync --frozen --no-dev
    ${pkgs.uv}/bin/uv pip install --python .venv/bin/python \
      'dagster>=1.11' \
      'dagster-webserver>=1.11' \
      'dagster-postgres>=0.27'

    exec .venv/bin/dagster code-server start \
      -m finances_dagster.definitions \
      -h 0.0.0.0 \
      -p ${toString cfg.port}
  '';
in
{
  options.modules.services.finances-dagster = {
    enable = mkBoolOpt false;

    gitUrl = mkOpt types.str "git@github.com:edmundmiller/finances.git";
    gitBranch = mkOpt types.str "main";

    repoPath = mkOpt types.str "/home/emiller/src/personal/finances";
    port = mkOpt types.port 4010;

    # Optional env file for extra runtime vars/secrets.
    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to env file loaded into dagster-code-finances.";
    };

    # Optional raw 1Password service-account token file.
    # When set, this module emits OP_SERVICE_ACCOUNT_TOKEN via EnvironmentFile.
    opTokenFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to raw OP service-account token file.";
    };

    dailyHealthcheckPingUrl = mkOpt types.str "";
  };

  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      modules.services.dagster = {
        enable = true;

        codeLocations = [
          {
            type = "grpc";
            name = "finances";
            host = "localhost";
            inherit (cfg) port;
            service = {
              enable = true;
              workingDirectory = cfg.repoPath;
              execStart = codeServerScript;
              environment = {
                BEANCOUNT_DAILY_HEALTHCHECK_URL = cfg.dailyHealthcheckPingUrl;
                UV_CACHE_DIR = "${dagsterCfg.home}/.cache/uv";
                UV_PYTHON_PREFERENCE = "system";
                # uv-managed Python on NixOS needs explicit CA bundle path.
                SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
                # Make subprocess calls in finances_dagster (just/op/etc.) deterministic.
                # PATH is set in the wrapper script to avoid conflicting with
                # systemd's module-provided PATH env.
                # 1Password CLI needs writable config/session path in service context.
                XDG_CONFIG_HOME = "/tmp";
              };
              environmentFiles =
                (optional (cfg.environmentFile != null) cfg.environmentFile)
                ++ (optional (cfg.opTokenFile != null) opEnvFile);
              readWritePaths = [
                cfg.repoPath
                "${dagsterCfg.home}/.cache"
              ];
            };
          }
        ];
      };

      # Clone repo once (if missing) before code server starts.
      systemd.services.finances-dagster-setup = {
        description = "Finances Dagster repo setup";
        wantedBy = [ "multi-user.target" ];
        before = [ "dagster-code-finances.service" ];
        after = [
          "network-online.target"
          "systemd-resolved.service"
        ];
        wants = [ "network-online.target" ];

        serviceConfig = {
          Type = "oneshot";
          User = dagsterCfg.user;
          Group = dagsterCfg.group;
          ExecStart = setupScript;
          Restart = "on-failure";
          RestartSec = "10s";
          RestartMaxDelaySec = "60s";
        };

        environment = {
          GIT_TERMINAL_PROMPT = "0";
        };
      };

      # Fix ownership drift from older manual/local installs that created
      # repo artifacts (notably .venv) as root.
      systemd.services.finances-dagster-perms = {
        description = "Fix finances Dagster repo permissions";
        before = [ "dagster-code-finances.service" ];
        requiredBy = [ "dagster-code-finances.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "finances-dagster-perms" ''
            if [ -e ${escapeShellArg cfg.repoPath} ]; then
              chown -R ${dagsterCfg.user}:${dagsterCfg.group} ${escapeShellArg cfg.repoPath}
            fi
          '';
        };
      };

      # Convert raw token file to KEY=VALUE EnvironmentFile for systemd.
      systemd.services.finances-dagster-op-env = mkIf (cfg.opTokenFile != null) {
        description = "Generate finances Dagster OP env file";
        before = [ "dagster-code-finances.service" ];
        requiredBy = [ "dagster-code-finances.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "finances-dagster-op-env" ''
            printf 'OP_SERVICE_ACCOUNT_TOKEN=%s\n' "$(cat ${escapeShellArg cfg.opTokenFile})" > ${opEnvFile}
            chmod 600 ${opEnvFile}
          '';
        };
      };

      # Ensure code server waits for setup/token env generation.
      systemd.services.dagster-code-finances = {
        after = [
          "finances-dagster-setup.service"
          "finances-dagster-perms.service"
        ]
        ++ optional (cfg.opTokenFile != null) "finances-dagster-op-env.service";
        requires = [
          "finances-dagster-setup.service"
          "finances-dagster-perms.service"
        ]
        ++ optional (cfg.opTokenFile != null) "finances-dagster-op-env.service";
      };

      systemd.tmpfiles.rules = [
        "d ${dagsterCfg.home}/.cache 0750 ${dagsterCfg.user} ${dagsterCfg.group} -"
        "d ${dagsterCfg.home}/.cache/uv 0750 ${dagsterCfg.user} ${dagsterCfg.group} -"
      ];
    }
  );
}
