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
  cfg = config.modules.services.sparkyfitness;
  dataDir = "/var/lib/sparkyfitness";
  environmentFile =
    if cfg.environmentFile == null then "/run/agenix/missing-sparkyfitness-env" else toString cfg.environmentFile;
  tailnet = "cinnamon-rooster.ts.net";
  frontendUrl = "https://${cfg.tailscaleService.serviceName}.${tailnet}";

  composeText = ''
    services:
      sparkyfitness-db:
        image: postgres:18.3-alpine@sha256:54451ecb8ab38c24c3ec123f2fd501303a3a1856a5c66e98cecf2460d5e1e9d7
        container_name: sparkyfitness-db
        environment:
          POSTGRES_DB: ''${SPARKY_FITNESS_DB_NAME:?SPARKY_FITNESS_DB_NAME is required}
          POSTGRES_USER: ''${SPARKY_FITNESS_DB_USER:?SPARKY_FITNESS_DB_USER is required}
          POSTGRES_PASSWORD: ''${SPARKY_FITNESS_DB_PASSWORD:?SPARKY_FITNESS_DB_PASSWORD is required}
        volumes:
          - ${dataDir}/postgresql:/var/lib/postgresql
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
          interval: 5s
          timeout: 5s
          retries: 12
        restart: unless-stopped

      sparkyfitness-server:
        image: codewithcj/sparkyfitness_server:v0.17.3@sha256:6aa7d9832324ea403be144a26398a82afbf04abbb4da89f9d04ba61838516b3f
        container_name: sparkyfitness-server
        env_file:
          - ${environmentFile}
        environment:
          ALLOW_PRIVATE_NETWORK_CORS: "false"
          NODE_ENV: production
          SPARKY_FITNESS_DB_HOST: sparkyfitness-db
          SPARKY_FITNESS_DB_PORT: "5432"
          SPARKY_FITNESS_FRONTEND_URL: ${frontendUrl}
          SPARKY_FITNESS_FORCE_EMAIL_LOGIN: "true"
          SPARKY_FITNESS_LOG_LEVEL: ERROR
          SPARKY_FITNESS_PUBLIC_API_DOCS: "false"
          TZ: America/Chicago
        volumes:
          - ${dataDir}/backup:/app/SparkyFitnessServer/backup
          - ${dataDir}/uploads:/app/SparkyFitnessServer/uploads
        depends_on:
          sparkyfitness-db:
            condition: service_healthy
        healthcheck:
          test: ["CMD", "/usr/bin/curl", "-f", "http://127.0.0.1:3010/api/health"]
          interval: 5s
          timeout: 10s
          retries: 12
        restart: unless-stopped

      sparkyfitness-frontend:
        image: codewithcj/sparkyfitness:v0.17.3@sha256:46d90e46bd87312fcbbbb05036d99e4cb1c821e928b0516ee727de4c3c90752b
        container_name: sparkyfitness-frontend
        environment:
          SPARKY_FITNESS_FRONTEND_URL: ${frontendUrl}
          SPARKY_FITNESS_SERVER_HOST: sparkyfitness-server
          SPARKY_FITNESS_SERVER_PORT: "3010"
        ports:
          - "127.0.0.1:${toString cfg.port}:80"
        depends_on:
          sparkyfitness-server:
            condition: service_healthy
        healthcheck:
          test: ["CMD", "curl", "-f", "http://127.0.0.1/"]
          interval: 5s
          timeout: 10s
          retries: 12
        restart: unless-stopped
  '';
  composeFile = pkgs.writeText "sparkyfitness-compose.yml" composeText;

  compose = "${pkgs.unstable.docker-compose}/bin/docker-compose --project-name sparkyfitness --env-file ${environmentFile} -f ${composeFile}";
in
{
  options.modules.services.sparkyfitness = {
    enable = mkBoolOpt false;
    port = mkOpt types.port 3004;
    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Agenix environment file containing SparkyFitness database and application secrets.";
    };
    tailscaleService = {
      enable = mkBoolOpt false;
      serviceName = mkOpt types.str "sparkyfitness";
    };
    generatedCompose = mkOption {
      type = types.str;
      readOnly = true;
      internal = true;
      default = composeText;
    };
  };

  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      assertions = [
        {
          assertion = config.modules.services.docker.enable;
          message = "modules.services.sparkyfitness requires modules.services.docker.enable = true";
        }
        {
          assertion = cfg.environmentFile != null;
          message = "modules.services.sparkyfitness.environmentFile is required";
        }
      ];

      systemd.tmpfiles.rules = [
        "d ${dataDir} 0750 root root -"
        "d ${dataDir}/postgresql 0750 70 70 -"
        "d ${dataDir}/backup 0750 root root -"
        "d ${dataDir}/uploads 0750 root root -"
      ];

      systemd.services.sparkyfitness = {
        description = "SparkyFitness Docker Compose stack";
        wantedBy = [ "multi-user.target" ];
        after = [
          "docker.service"
          "network-online.target"
        ];
        wants = [ "network-online.target" ];
        requires = [ "docker.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${compose} up -d --remove-orphans --wait --wait-timeout 180";
          ExecStop = "${compose} down --timeout 60";
          TimeoutStartSec = "10min";
          TimeoutStopSec = "2min";
        };
      };

      systemd.services.sparkyfitness-tailscale-serve = mkIf cfg.tailscaleService.enable {
        description = "Tailscale Service proxy for SparkyFitness";
        wantedBy = [ "multi-user.target" ];
        after = [
          "sparkyfitness.service"
          "tailscaled.service"
        ];
        requires = [ "sparkyfitness.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.util-linux}/bin/flock /run/tailscale-serve.lock ${pkgs.bash}/bin/bash -c \"for i in \\$(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://127.0.0.1:${toString cfg.port} && exit 0; sleep 1; done; exit 1\"'";
          ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
        };
      };

      environment.systemPackages = [ pkgs.unstable.docker-compose ];
    }
  );
}
