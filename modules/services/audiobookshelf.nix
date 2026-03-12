# Audiobookshelf - self-hosted audiobooks and podcasts
# Tailscale: https://audiobookshelf.<tailnet>.ts.net
# Direct: http://<tailscale-ip>:13378
#
# Setup (one-time):
# 1. Tailscale admin → Services → Create service
# 2. Name: "audiobookshelf", endpoint: tcp:443, tag: tag:server
# 3. Deploy: hey nuc
# 4. Approve host in admin console
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
  cfg = config.modules.services.audiobookshelf;
in
{
  options.modules.services.audiobookshelf = {
    enable = mkBoolOpt false;
    port = mkOpt types.port 13378;

    tailscaleService = {
      enable = mkBoolOpt false;
      serviceName = mkOpt types.str "audiobookshelf";
    };
  };

  # NixOS-only service
  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      services.audiobookshelf = {
        enable = true;
        openFirewall = true;
        host = "0.0.0.0";
        inherit (cfg) port;
      };

      user.extraGroups = [ "audiobookshelf" ];
      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cfg.port ];

      systemd.services.audiobookshelf-tailscale-serve = mkIf cfg.tailscaleService.enable {
        description = "Tailscale Service proxy for Audiobookshelf";
        wantedBy = [ "multi-user.target" ];
        after = [
          "audiobookshelf.service"
          "tailscaled.service"
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.util-linux}/bin/flock /run/tailscale-serve.lock ${pkgs.bash}/bin/bash -c \"for i in \\$(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://localhost:${toString cfg.port} && exit 0; sleep 1; done; exit 1\"'";
          ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
        };
      };
    }
  );
}
