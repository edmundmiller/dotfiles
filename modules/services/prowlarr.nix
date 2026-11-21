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
  cfg = config.modules.services.prowlarr;
in
{
  options.modules.services.prowlarr = {
    enable = mkBoolOpt false;
    tailscaleService = {
      enable = mkBoolOpt false;
      serviceName = mkOpt types.str "prowlarr";
    };
  }
  // lib.my.mkRegistry {
    gatus = {
      name = "Prowlarr";
      order = 70;
      group = "Media";
      url = "http://localhost:9696/ping";
      conditions = [ "[STATUS] == 200" ];
      alerts = true;
    };
    homepage = {
      group = "Downloads";
      name = "Prowlarr";
      order = 30;
      href =
        if cfg.tailscaleService.enable then
          "https://${cfg.tailscaleService.serviceName}.cinnamon-rooster.ts.net"
        else
          "http://nuc.cinnamon-rooster.ts.net:9696";
      description = "Indexer manager";
      icon = "prowlarr.svg";
    };
  };

  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      services.prowlarr.enable = true;
      services.prowlarr.openFirewall = true;

      systemd.services.prowlarr-tailscale-serve = mkIf cfg.tailscaleService.enable {
        description = "Tailscale Service proxy for Prowlarr";
        wantedBy = [ "multi-user.target" ];
        after = [
          "prowlarr.service"
          "tailscaled.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.util-linux}/bin/flock /run/tailscale-serve.lock ${pkgs.bash}/bin/bash -c \"for i in \\$(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://127.0.0.1:9696 && exit 0; sleep 1; done; exit 1\"'";
          ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
        };
      };
    }
  );
}
