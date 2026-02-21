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
  };

  # NixOS-only service
  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      services.lubelogger = {
        enable = true;
        openFirewall = true;
        environmentFile = cfg.environmentFile;
      };

      # Upstream module binds to localhost only — override to allow Tailscale access
      systemd.services.lubelogger.environment.Kestrel__Endpoints__Http__Url =
        lib.mkForce "http://0.0.0.0:${toString config.services.lubelogger.port}";

    }
  );
}
