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
  cfg = config.modules.services.radarr;
in
{
  options.modules.services.radarr = {
    enable = mkBoolOpt false;
    tailscaleService = {
      enable = mkBoolOpt false;
      serviceName = mkOpt types.str "radarr";
    };
  }
  // lib.my.mkRegistry {
    gatus = {
      name = "Radarr";
      order = 60;
      group = "Media";
      url = "http://localhost:7878/ping";
      conditions = [ "[STATUS] == 200" ];
      alerts = true;
    };
    homepage = {
      group = "Downloads";
      name = "Radarr";
      order = 10;
      href =
        if cfg.tailscaleService.enable then
          "https://${cfg.tailscaleService.serviceName}.cinnamon-rooster.ts.net"
        else
          "http://nuc.cinnamon-rooster.ts.net:7878";
      description = "Movies";
      icon = "radarr.svg";
    };
  };

  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      services.radarr.enable = true;
      services.radarr.openFirewall = true;

      systemd.services.radarr-tailscale-serve = mkIf cfg.tailscaleService.enable {
        description = "Tailscale Service proxy for Radarr";
        wantedBy = [ "multi-user.target" ];
        after = [
          "radarr.service"
          "tailscaled.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.util-linux}/bin/flock /run/tailscale-serve.lock ${pkgs.bash}/bin/bash -c \"for i in \\$(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://127.0.0.1:7878 && exit 0; sleep 1; done; exit 1\"'";
          ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
        };
      };
    }
  );
}
