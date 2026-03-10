# Open Wearables - self-hosted wearable data API (Apple XML import friendly)
# Tailscale: https://open-wearables.<tailnet>.ts.net
# Direct API docs: http://<tailscale-ip>:18100/docs
#
# Notes:
# - Runs upstream stack via docker-compose (backend + worker + beat + postgres + redis)
# - Frontend is optional (disabled by default)
# - Backend .env is generated automatically; SECRET_KEY + admin password are persisted in dataDir/.state
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
  cfg = config.modules.services.open-wearables;

  composeFile = pkgs.writeText "open-wearables-compose.yml" ''
        services:
          db:
            image: postgres:17
            container_name: postgres__open-wearables
            environment:
              POSTGRES_DB: open-wearables
              POSTGRES_USER: open-wearables
              POSTGRES_PASSWORD: open-wearables
            healthcheck:
              test: ["CMD-SHELL", "pg_isready -U open-wearables -d open-wearables"]
              interval: 5s
              timeout: 5s
              retries: 5
            volumes:
              - ${cfg.dataDir}/postgres:/var/lib/postgresql/data
            restart: unless-stopped

          redis:
            image: redis:8
            container_name: redis__open-wearables
            volumes:
              - ${cfg.dataDir}/redis:/data
            restart: unless-stopped

          app:
            build:
              context: ${cfg.dataDir}/backend
              dockerfile: Dockerfile
            container_name: backend__open-wearables
            image: open-wearables-platform:latest
            command: scripts/start/app.sh
            env_file:
              - ${cfg.dataDir}/backend/config/.env
    ${
      optionalString (cfg.environmentFile != null) "          - ${cfg.environmentFile}\n"
    }        environment:
              DB_HOST: db
              REDIS_HOST: redis
            ports:
              - "${toString cfg.backendPort}:8000"
            depends_on:
              db:
                condition: service_healthy
              redis:
                condition: service_started
            restart: on-failure

          celery-worker:
            image: open-wearables-platform:latest
            container_name: celery-worker__open-wearables
            command: scripts/start/worker.sh
            env_file:
              - ${cfg.dataDir}/backend/config/.env
    ${
      optionalString (cfg.environmentFile != null) "          - ${cfg.environmentFile}\n"
    }        environment:
              DB_HOST: db
              REDIS_HOST: redis
            depends_on:
              - db
              - redis
              - app
            restart: on-failure

          celery-beat:
            image: open-wearables-platform:latest
            container_name: celery-beat__open-wearables
            command: scripts/start/beat.sh
            env_file:
              - ${cfg.dataDir}/backend/config/.env
    ${
      optionalString (cfg.environmentFile != null) "          - ${cfg.environmentFile}\n"
    }        environment:
              DB_HOST: db
              REDIS_HOST: redis
            depends_on:
              - db
              - redis
              - app
            restart: on-failure
    ${optionalString cfg.enableFlower ''

      flower:
        image: open-wearables-platform:latest
        container_name: flower__open-wearables
        command: scripts/start/flower.sh
        env_file:
          - ${cfg.dataDir}/backend/config/.env
    ''}${
      optionalString (
        cfg.enableFlower && cfg.environmentFile != null
      ) "          - ${cfg.environmentFile}\n"
    }${optionalString cfg.enableFlower ''
      environment:
        DB_HOST: db
        REDIS_HOST: redis
      ports:
        - "${toString cfg.flowerPort}:5555"
      depends_on:
        - db
        - redis
        - app
      restart: on-failure
    ''}${optionalString cfg.enableFrontend ''

      frontend:
        build:
          context: ${cfg.dataDir}/frontend
          dockerfile: Dockerfile.dev
        container_name: frontend__open-wearables
        image: open-wearables-frontend:dev
        env_file:
          - ${cfg.dataDir}/frontend/.env
        depends_on:
          - app
        ports:
          - "${toString cfg.frontendPort}:3000"
        restart: on-failure
    ''}
  '';

  setupScript = pkgs.writeShellScript "open-wearables-setup" ''
        set -euo pipefail

        REPO_DIR=${escapeShellArg cfg.dataDir}
        STATE_DIR="$REPO_DIR/.state"

        mkdir -p "$REPO_DIR" "$STATE_DIR" "$REPO_DIR/postgres" "$REPO_DIR/redis"

        if [ ! -d "$REPO_DIR/.git" ]; then
          ${pkgs.git}/bin/git -C "$REPO_DIR" init
        fi
        if ! ${pkgs.git}/bin/git -C "$REPO_DIR" remote get-url origin >/dev/null 2>&1; then
          ${pkgs.git}/bin/git -C "$REPO_DIR" remote add origin ${escapeShellArg cfg.gitUrl}
        else
          ${pkgs.git}/bin/git -C "$REPO_DIR" remote set-url origin ${escapeShellArg cfg.gitUrl}
        fi

        cd "$REPO_DIR"
        ${pkgs.git}/bin/git fetch origin
        ${pkgs.git}/bin/git reset --hard "origin/${cfg.gitBranch}"

        if [ ! -s "$STATE_DIR/secret_key" ]; then
          ${pkgs.openssl}/bin/openssl rand -hex 64 > "$STATE_DIR/secret_key"
          chmod 600 "$STATE_DIR/secret_key"
        fi

        if [ ! -s "$STATE_DIR/admin_password" ]; then
          ${pkgs.openssl}/bin/openssl rand -base64 24 | tr -d '\n' > "$STATE_DIR/admin_password"
          chmod 600 "$STATE_DIR/admin_password"
        fi

        SECRET_KEY=$(cat "$STATE_DIR/secret_key")
        ADMIN_PASSWORD=$(cat "$STATE_DIR/admin_password")

        cat > "$REPO_DIR/backend/config/.env" <<EOF
    ENVIRONMENT=production
    CORS_ORIGINS=["http://localhost:${toString cfg.frontendPort}"]
    SERVER_HOST=http://localhost:${toString cfg.backendPort}
    FRONTEND_URL=http://localhost:${toString cfg.frontendPort}

    DB_HOST=db
    DB_PORT=5432
    DB_NAME=open-wearables
    DB_USER=open-wearables
    DB_PASSWORD=open-wearables

    REDIS_HOST=redis
    REDIS_PORT=6379
    REDIS_DB=0

    SENTRY_ENABLED=False

    SECRET_KEY=$SECRET_KEY
    ADMIN_EMAIL=${cfg.adminEmail}
    ADMIN_PASSWORD=$ADMIN_PASSWORD
    EOF

        cat > "$REPO_DIR/frontend/.env" <<EOF
    VITE_API_URL=http://localhost:${toString cfg.backendPort}
    NODE_ENV=production
    EOF

        cp ${composeFile} "$REPO_DIR/docker-compose.nuc.yml"

        chmod 600 "$REPO_DIR/backend/config/.env"
        chmod 644 "$REPO_DIR/frontend/.env"

        echo "open-wearables configured"
  '';

  composeCmd = "${pkgs.unstable.docker-compose}/bin/docker-compose -f ${cfg.dataDir}/docker-compose.nuc.yml";
in
{
  options.modules.services.open-wearables = {
    enable = mkBoolOpt false;

    gitUrl = mkOpt types.str "https://github.com/the-momentum/open-wearables.git";
    gitBranch = mkOpt types.str "main";

    dataDir = mkOpt types.str "/var/lib/open-wearables";

    backendPort = mkOpt types.port 18100;
    frontendPort = mkOpt types.port 18101;
    flowerPort = mkOpt types.port 18155;

    enableFrontend = mkBoolOpt false;
    enableFlower = mkBoolOpt false;

    adminEmail = mkOpt types.str "admin@openwearables.dev";

    # Optional extra backend env file (agenix recommended for secrets/provider creds).
    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to extra backend env file (e.g. provider OAuth/AWS creds).";
    };

    tailscaleService = {
      enable = mkBoolOpt true;
      serviceName = mkOpt types.str "open-wearables";
    };
  };

  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      assertions = [
        {
          assertion = config.modules.services.docker.enable;
          message = "modules.services.open-wearables requires modules.services.docker.enable = true";
        }
      ];

      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0750 root root -"
        "d ${cfg.dataDir}/.state 0700 root root -"
        "d ${cfg.dataDir}/postgres 0750 root root -"
        "d ${cfg.dataDir}/redis 0750 root root -"
      ];

      systemd.services.open-wearables-setup = {
        description = "Open Wearables setup (clone + env generation)";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        before = [ "open-wearables.service" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = setupScript;
        };
      };

      systemd.services.open-wearables = {
        description = "Open Wearables docker-compose stack";
        wantedBy = [ "multi-user.target" ];
        after = [
          "docker.service"
          "network-online.target"
          "open-wearables-setup.service"
        ];
        wants = [ "network-online.target" ];
        requires = [
          "docker.service"
          "open-wearables-setup.service"
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          WorkingDirectory = cfg.dataDir;
          ExecStart = "${composeCmd} up -d --build --remove-orphans";
          ExecStop = "${composeCmd} down";
          TimeoutStartSec = "30min";
          TimeoutStopSec = "5min";
        };
      };

      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
        cfg.backendPort
      ]
      ++ optionals cfg.enableFrontend [ cfg.frontendPort ]
      ++ optionals cfg.enableFlower [ cfg.flowerPort ];

      systemd.services.open-wearables-tailscale-serve = mkIf cfg.tailscaleService.enable {
        description = "Tailscale Service proxy for Open Wearables API";
        wantedBy = [ "multi-user.target" ];
        after = [
          "open-wearables.service"
          "tailscaled.service"
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.util-linux}/bin/flock /run/tailscale-serve.lock ${pkgs.bash}/bin/bash -c \"for i in \\$(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://localhost:${toString cfg.backendPort} && exit 0; sleep 1; done; exit 1\"'";
          ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
        };
      };

      environment.systemPackages = [ pkgs.unstable.docker-compose ];
    }
  );
}
