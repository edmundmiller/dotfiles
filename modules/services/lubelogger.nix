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
        environmentFile = cfg.environmentFile;
      };
    }
  );
}
