# Speedtest Tracker - Scheduled internet speed history
# Dashboard: https://speedtest-tracker.cinnamon-rooster.ts.net
#
# Setup (one-time, after first deploy):
# 1. Open https://speedtest-tracker.cinnamon-rooster.ts.net
# 2. Create admin account
# 3. Settings -> API -> create token for homepage widget
# 4. Add token as HOMEPAGE_VAR_SPEEDTEST_API_KEY in homepage-env.age
#
# Secrets (environmentFile must contain):
#   APP_KEY=base64:<32-byte-key>   # generate: openssl rand -base64 32
#
# Homepage widget (version 2):
#   widget.type = "speedtest";
#   widget.url = "http://localhost:8765";
#   widget.version = 2;
#   widget.key = "{{HOMEPAGE_VAR_SPEEDTEST_API_KEY}}";
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
  cfg = config.modules.services.speedtest-tracker;
  inherit (cfg) port;
  dataDir = "/var/lib/speedtest-tracker";
in
{
  options.modules.services.speedtest-tracker = {
    enable = mkBoolOpt false;
    port = mkOpt types.port 8765;
    tailscaleService = {
      enable = mkBoolOpt false;
      serviceName = mkOpt types.str "speedtest-tracker";
    };
    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to env file containing APP_KEY and any other secrets.";
    };
    schedule = mkOpt types.str "0 * * * *"; # hourly by default
    timezone = mkOpt types.str "America/Chicago";
  }
  // lib.my.mkRegistry {
    gatus = {
      name = "Speedtest Tracker";
      order = 150;
      group = "Network";
      url = "http://localhost:${toString cfg.port}/admin/login";
      conditions = [ "[STATUS] == 200" ];
    };
    homepage = {
      group = "Network";
      name = "Speedtest Tracker";
      order = 40;
      description = "Network speed history";
      icon = "mdi-speedometer";
      href =
        if cfg.tailscaleService.enable then
          "https://${cfg.tailscaleService.serviceName}.cinnamon-rooster.ts.net"
        else
          "http://nuc.cinnamon-rooster.ts.net:${toString cfg.port}";
    };
  };

  # NixOS-only service (OCI container)
  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      virtualisation.oci-containers.containers."speedtest-tracker" = {
        autoStart = true;
        image = "lscr.io/linuxserver/speedtest-tracker:latest";
        ports = [ "0.0.0.0:${toString cfg.port}:80" ];
        volumes = [ "${dataDir}:/config:rw" ];
        environment = {
          PUID = "1000";
          PGID = "100";
          TZ = cfg.timezone;
          SPEEDTEST_SCHEDULE = cfg.schedule;
          DB_CONNECTION = "sqlite";
        }
        // optionalAttrs cfg.tailscaleService.enable {
          APP_URL = "https://${cfg.tailscaleService.serviceName}.cinnamon-rooster.ts.net";
        };
        environmentFiles = optional (cfg.environmentFile != null) cfg.environmentFile;
      };

      systemd.tmpfiles.rules = [
        "d ${dataDir} 0750 1000 100 -"
      ];

      networking.firewall.allowedTCPPorts = [ port ];

      systemd.services.speedtest-tracker-tailscale-serve = mkIf cfg.tailscaleService.enable {
        description = "Tailscale Service proxy for Speedtest Tracker";
        wantedBy = [ "multi-user.target" ];
        after = [
          "${config.virtualisation.oci-containers.backend}-speedtest-tracker.service"
          "tailscaled.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.util-linux}/bin/flock /run/tailscale-serve.lock ${pkgs.bash}/bin/bash -c \"for i in \\$(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://127.0.0.1:${toString cfg.port} && exit 0; sleep 1; done; exit 1\"'";
          ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
        };
      };
    }
  );
}
