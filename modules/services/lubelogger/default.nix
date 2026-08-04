# LubeLogger - Vehicle maintenance & fuel mileage tracker
# Dashboard: http://<nuc-tailscale-ip>:5000
#
# Home Assistant integration (HACS):
#   Repo: https://github.com/hollowpnt92/lubelogger-ha
#   Provides sensors per vehicle: odometer, next reminder, service/repair/fuel records
#   Install via HACS → Custom Repositories → add URL above
{
  config,
  lib,
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
      href = "http://nuc.cinnamon-rooster.ts.net:5000";
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

    }
  );
}
