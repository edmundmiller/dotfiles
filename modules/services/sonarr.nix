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
  cfg = config.modules.services.sonarr;
in
{
  options.modules.services.sonarr = {
    enable = mkBoolOpt false;
    tailscaleService = {
      enable = mkBoolOpt false;
      serviceName = mkOpt types.str "sonarr";
    };
  }
  // lib.my.mkRegistry {
    gatus = {
      name = "Sonarr";
      order = 50;
      group = "Media";
      url = "http://localhost:8989/ping";
      conditions = [ "[STATUS] == 200" ];
      alerts = true;
    };
    homepage = {
      group = "Downloads";
      name = "Sonarr";
      order = 20;
      href =
        if cfg.tailscaleService.enable then
          "https://${cfg.tailscaleService.serviceName}.cinnamon-rooster.ts.net"
        else
          "http://nuc.cinnamon-rooster.ts.net:8989";
      description = "TV shows";
      icon = "sonarr.svg";
    };
  };

  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      services.sonarr.enable = true;
      services.sonarr.openFirewall = true;

      systemd.services.sonarr-tailscale-serve = mkIf cfg.tailscaleService.enable {
        description = "Tailscale Service proxy for Sonarr";
        wantedBy = [ "multi-user.target" ];
        after = [
          "sonarr.service"
          "tailscaled.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.util-linux}/bin/flock /run/tailscale-serve.lock ${pkgs.bash}/bin/bash -c \"for i in \\$(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://127.0.0.1:8989 && exit 0; sleep 1; done; exit 1\"'";
          ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
        };
      };
    }
  );
}
