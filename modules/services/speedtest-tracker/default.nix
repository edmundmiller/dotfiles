# Speedtest Tracker - Scheduled internet speed history
# Dashboard: http://<nuc-tailscale-ip>:8765
#
# Setup (one-time, after first deploy):
# 1. Open http://nuc.<tailnet>:8765
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
    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to env file containing APP_KEY and any other secrets.";
    };
    schedule = mkOpt types.str "0 * * * *"; # hourly by default
    timezone = mkOpt types.str "America/Chicago";
  };

  # NixOS-only service (OCI container)
  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      virtualisation.oci-containers.containers."speedtest-tracker" = {
        autoStart = true;
        image = "lscr.io/linuxserver/speedtest-tracker:latest";
        ports = [ "0.0.0.0:${toString port}:80" ];
        volumes = [ "${dataDir}:/config:rw" ];
        environment = {
          PUID = "1000";
          PGID = "100";
          TZ = cfg.timezone;
          SPEEDTEST_SCHEDULE = cfg.schedule;
          DB_CONNECTION = "sqlite";
        };
        environmentFiles = optional (cfg.environmentFile != null) cfg.environmentFile;
      };

      systemd.tmpfiles.rules = [
        "d ${dataDir} 0750 root root -"
      ];

      networking.firewall.allowedTCPPorts = [ port ];
    }
  );
}
