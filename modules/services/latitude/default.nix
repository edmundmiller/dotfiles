# Latitude LLM self-hosted stack.
# Tailscale services:
# - https://latitude-web.cinnamon-rooster.ts.net
# - https://latitude-api.cinnamon-rooster.ts.net
# - https://latitude-ingest.cinnamon-rooster.ts.net
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
  cfg = config.modules.services.latitude;
  tailnet = "cinnamon-rooster.ts.net";

  latitudeRevision = "85fd1e64868cabe73fe0bf42b12fdbc3bb3f0ae6";
  upstreamBase = "https://raw.githubusercontent.com/latitude-dev/latitude-llm/${latitudeRevision}";
  fetchAsset =
    path: hash:
    pkgs.fetchurl {
      url = "${upstreamBase}/${path}";
      inherit hash;
    };

  dockerStack = fetchAsset "docker-stack.yml" "sha256-2hzlD59qF6OvICpMzt9COotFL+NpzFO+IJrkQ3oiiIo=";
  initDb = fetchAsset "docker/init-db.sh" "sha256-juhPgiZuXodoKuKp3ixGrCY9csp4cNImmvhFak/jzyg=";
  seaweedInit = fetchAsset "docker/seaweedfs/init.sh" "sha256-EYNJxJN7E/iXeEivpRv7IY79T5JwCREIKWN7ymTbDs4=";
  clickhouseStorage = fetchAsset "docker/clickhouse/storage.xml" "sha256-1HjUYhjp1edGtgOx2fK+FMGYMS4TDjFTrPn+12KOMfg=";

  webUrl = "https://${cfg.tailscaleServices.webName}.${tailnet}";
  apiUrl = "https://${cfg.tailscaleServices.apiName}.${tailnet}";
  ingestUrl = "https://${cfg.tailscaleServices.ingestName}.${tailnet}";

  composeCmd = "${pkgs.unstable.docker-compose}/bin/docker-compose --env-file .env.production -f docker-stack.yml";

  setupScript = pkgs.writeShellScript "latitude-setup" ''
    set -euo pipefail

    data_dir=${escapeShellArg cfg.dataDir}
    secrets_file=${escapeShellArg cfg.environmentFile}
    env_file="$data_dir/.env.production"

    install -d -m 0750 "$data_dir" "$data_dir/docker" "$data_dir/docker/seaweedfs" "$data_dir/docker/clickhouse"
    install -m 0644 ${dockerStack} "$data_dir/docker-stack.yml"
    install -m 0755 ${initDb} "$data_dir/docker/init-db.sh"
    install -m 0755 ${seaweedInit} "$data_dir/docker/seaweedfs/init.sh"
    install -m 0644 ${clickhouseStorage} "$data_dir/docker/clickhouse/storage.xml"

    ${pkgs.gnused}/bin/sed -i \
      -e 's/"3000:3000"/"127.0.0.1:3000:3000"/' \
      -e 's/"3001:3001"/"127.0.0.1:3001:3001"/' \
      -e 's/"3002:3002"/"127.0.0.1:3002:3002"/' \
      "$data_dir/docker-stack.yml"

    set -a
    . "$secrets_file"
    set +a

    cat > "$env_file" <<EOF
    POSTGRES_USER=latitude
    POSTGRES_PASSWORD=$LATITUDE_POSTGRES_PASSWORD
    POSTGRES_DB=latitude
    POSTGRES_RUNTIME_USER=latitude_app
    POSTGRES_RUNTIME_PASSWORD=$LATITUDE_POSTGRES_RUNTIME_PASSWORD

    CLICKHOUSE_USER=latitude
    CLICKHOUSE_PASSWORD=$LATITUDE_CLICKHOUSE_PASSWORD
    CLICKHOUSE_DB=latitude

    NODE_ENV=production
    LAT_IMAGE_TAG=${cfg.imageTag}

    LAT_CLICKHOUSE_URL=http://clickhouse:8123
    LAT_CLICKHOUSE_USER=latitude
    LAT_CLICKHOUSE_PASSWORD=$LATITUDE_CLICKHOUSE_PASSWORD
    LAT_CLICKHOUSE_DB=latitude
    LAT_CLICKHOUSE_MIGRATION_URL=clickhouse://clickhouse:9000
    LAT_CLICKHOUSE_CLUSTER_ENABLED=false

    LAT_DATABASE_URL=postgres://latitude_app:$LATITUDE_POSTGRES_RUNTIME_PASSWORD@postgres:5432/latitude
    LAT_PG_POOL_MAX=20
    LAT_PG_IDLE_TIMEOUT_MS=30000
    LAT_PG_CONNECT_TIMEOUT_MS=10000
    LAT_ADMIN_DATABASE_URL=postgres://latitude:$LATITUDE_POSTGRES_PASSWORD@postgres:5432/latitude

    LAT_REDIS_HOST=redis
    LAT_REDIS_PORT=6379
    LAT_BULLMQ_HOST=redis-bullmq
    LAT_BULLMQ_PORT=6379
    LAT_BULL_BOARD_USERNAME=admin
    LAT_BULL_BOARD_PASSWORD=$LATITUDE_BULL_BOARD_PASSWORD

    LAT_TEMPORAL_ADDRESS=temporal:7233
    LAT_TEMPORAL_NAMESPACE=default
    LAT_TEMPORAL_TASK_QUEUE=latitude-workflows

    LAT_STORAGE_DRIVER=s3
    LAT_STORAGE_S3_BUCKET=latitude
    LAT_STORAGE_S3_REGION=us-east-1
    LAT_STORAGE_S3_ACCESS_KEY_ID=latitude
    LAT_STORAGE_S3_SECRET_ACCESS_KEY=$LATITUDE_STORAGE_S3_SECRET_ACCESS_KEY
    LAT_STORAGE_S3_ENDPOINT=http://seaweedfs:8333
    LAT_STORAGE_S3_FORCE_PATH_STYLE=true

    LAT_WEB_URL=${webUrl}
    LAT_WEB_PORT=${toString cfg.webPort}
    LAT_API_URL=${apiUrl}
    LAT_API_PORT=${toString cfg.apiPort}
    LAT_INGEST_URL=${ingestUrl}
    LAT_INGEST_PORT=${toString cfg.ingestPort}
    LAT_TRACE_SEARCH_SHARED_MESSAGE_EMBEDDINGS_READS=true

    LAT_MASTER_ENCRYPTION_KEY=$LAT_MASTER_ENCRYPTION_KEY
    LAT_BETTER_AUTH_SECRET=$LAT_BETTER_AUTH_SECRET

    LAT_TRUSTED_ORIGINS=${webUrl}
    LAT_CORS_ALLOWED_ORIGINS=${webUrl}
    LAT_AWS_REGION=us-east-1
    LAT_VOYAGE_API_KEY=
    EOF

    chmod 600 "$env_file"
  '';

  mkTailscaleServeService = name: port: afterUnit: {
    description = "Tailscale Service proxy for Latitude ${name}";
    wantedBy = [ "multi-user.target" ];
    after = [
      afterUnit
      "tailscaled.service"
    ];
    requires = [ afterUnit ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.util-linux}/bin/flock /run/tailscale-serve.lock ${pkgs.bash}/bin/bash -c \"for i in \\$(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${name} --https=443 http://127.0.0.1:${toString port} && exit 0; sleep 1; done; exit 1\"'";
      ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${name} || true'";
    };
  };
in
{
  options.modules.services.latitude = {
    enable = mkBoolOpt false;
    dataDir = mkOpt types.str "/var/lib/latitude";
    imageTag = mkOpt types.str "latest";
    webPort = mkOpt types.port 3000;
    apiPort = mkOpt types.port 3001;
    ingestPort = mkOpt types.port 3002;

    environmentFile = mkOption {
      type = types.path;
      description = "Agenix env file with Latitude secret seed values.";
    };

    tailscaleServices = {
      enable = mkBoolOpt true;
      webName = mkOpt types.str "latitude-web";
      apiName = mkOpt types.str "latitude-api";
      ingestName = mkOpt types.str "latitude-ingest";
    };
  };

  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      assertions = [
        {
          assertion = config.modules.services.docker.enable;
          message = "modules.services.latitude requires modules.services.docker.enable = true";
        }
      ];

      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0750 root root -"
      ];

      systemd.services.latitude-setup = {
        description = "Latitude setup";
        wantedBy = [ "multi-user.target" ];
        before = [ "latitude-compose.service" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = setupScript;
        };
      };

      systemd.services.latitude-compose = {
        description = "Latitude docker-compose stack";
        wantedBy = [ "multi-user.target" ];
        after = [
          "docker.service"
          "network-online.target"
          "latitude-setup.service"
        ];
        wants = [ "network-online.target" ];
        requires = [
          "docker.service"
          "latitude-setup.service"
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          WorkingDirectory = cfg.dataDir;
          ExecStart = "${composeCmd} up -d --remove-orphans";
          ExecStop = "${composeCmd} down";
          TimeoutStartSec = "30min";
          TimeoutStopSec = "5min";
        };
      };

      systemd.services.latitude-web-tailscale-serve = mkIf cfg.tailscaleServices.enable (
        mkTailscaleServeService cfg.tailscaleServices.webName cfg.webPort "latitude-compose.service"
      );
      systemd.services.latitude-api-tailscale-serve = mkIf cfg.tailscaleServices.enable (
        mkTailscaleServeService cfg.tailscaleServices.apiName cfg.apiPort "latitude-compose.service"
      );
      systemd.services.latitude-ingest-tailscale-serve = mkIf cfg.tailscaleServices.enable (
        mkTailscaleServeService cfg.tailscaleServices.ingestName cfg.ingestPort "latitude-compose.service"
      );

      environment.systemPackages = [ pkgs.unstable.docker-compose ];
    }
  );
}
