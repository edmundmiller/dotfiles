{
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.deploy-rs;
in
{
  options.modules.services.deploy-rs = {
    enable = mkBoolOpt false;
  };

  # Only apply on NixOS - Darwin doesn't use sudo for activation
  config = optionalAttrs (!isDarwin) (mkIf cfg.enable {
    # Passwordless sudo for deploy-rs activation (agentic deployments)
    security.sudo.extraRules = [
      {
        users = [ config.user.name ];
        commands = [
          { command = "ALL"; options = [ "NOPASSWD" ]; }
        ];
      }
    ];
  });
}
