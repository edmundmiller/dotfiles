# LubeLogger - Vehicle maintenance & fuel mileage tracker
# Dashboard: https://lubelogger.cinnamon-rooster.ts.net
#
# Home Assistant integration (HACS):
#   Repo: https://github.com/hollowpnt92/lubelogger-ha
#   Provides sensors per vehicle: odometer, next reminder, service/repair/fuel records
#   Install via HACS → Custom Repositories → add URL above
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
  cfg = config.modules.services.lubelogger;
in
{
  options.modules.services.lubelogger = {
    enable = mkBoolOpt false;
    tailscaleService = {
      enable = mkBoolOpt false;
      serviceName = mkOpt types.str "lubelogger";
    };
    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to env file for secrets (e.g. LUBELOGGER_ALLOWED_USERS).";
    };
  }
  // lib.my.mkRegistry {
    gatus = {
      name = "LubeLogger";
      order = 110;
      group = "Home";
      url = "http://localhost:5000";
      conditions = [ "[STATUS] < 500" ];
    };
    homepage = {
      group = "Home";
      name = "LubeLogger";
      order = 30;
      description = "Vehicle maintenance tracker";
      icon = "lubelogger.svg";
      href =
        if cfg.tailscaleService.enable then
          "https://${cfg.tailscaleService.serviceName}.cinnamon-rooster.ts.net"
        else
          "http://nuc.cinnamon-rooster.ts.net:5000";
      widget = {
        type = "lubelogger";
        url = "http://localhost:5000";
        username = "{{HOMEPAGE_VAR_LUBELOGGER_USERNAME}}";
        password = "{{HOMEPAGE_VAR_LUBELOGGER_PASSWORD}}";
      };
    };
  };

  # NixOS-only service
  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      services.lubelogger = {
        enable = true;
        openFirewall = true;
        inherit (cfg) environmentFile;
      };

      # Upstream module binds to localhost only — override to allow Tailscale access
      systemd.services.lubelogger.environment.Kestrel__Endpoints__Http__Url =
        lib.mkForce "http://0.0.0.0:${toString config.services.lubelogger.port}";

      systemd.services.lubelogger-tailscale-serve = mkIf cfg.tailscaleService.enable {
        description = "Tailscale Service proxy for LubeLogger";
        wantedBy = [ "multi-user.target" ];
        after = [
          "lubelogger.service"
          "tailscaled.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.util-linux}/bin/flock /run/tailscale-serve.lock ${pkgs.bash}/bin/bash -c \"for i in \\$(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://127.0.0.1:${toString config.services.lubelogger.port} && exit 0; sleep 1; done; exit 1\"'";
          ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
        };
      };
    }
  );
}
