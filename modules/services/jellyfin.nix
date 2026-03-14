# Jellyfin - self-hosted media server
# Tailscale: https://jellyfin.<tailnet>.ts.net
# Direct: http://<tailscale-ip>:8096
#
# Setup (one-time):
# 1. Tailscale admin → Services → Create service
# 2. Name: "jellyfin", endpoint: tcp:443, tag: tag:server
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
  cfg = config.modules.services.jellyfin;
in
{
  options.modules.services.jellyfin = {
    enable = mkBoolOpt false;

    tailscaleService = {
      enable = mkBoolOpt false;
      serviceName = mkOpt types.str "jellyfin";
    };
  };

  # NixOS-only service
  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      services.jellyfin = {
        enable = true;
        openFirewall = true;
      };

      user.extraGroups = [ "jellyfin" ];
      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8096 ];

      systemd.services.jellyfin-tailscale-serve = mkIf cfg.tailscaleService.enable {
        description = "Tailscale Service proxy for Jellyfin";
        wantedBy = [ "multi-user.target" ];
        after = [
          "jellyfin.service"
          "tailscaled.service"
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.util-linux}/bin/flock /run/tailscale-serve.lock ${pkgs.bash}/bin/bash -c \"for i in \\$(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://localhost:8096 && exit 0; sleep 1; done; exit 1\"'";
          ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
        };
      };
    }
  );
}
