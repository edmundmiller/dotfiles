{
  options,
  config,
  lib,
  pkgs,
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
    user = mkOpt types.str config.user.name "User to grant passwordless sudo for deployments";
  };

  # Only apply on NixOS - Darwin doesn't use sudo for activation
  config = mkIf (cfg.enable && !isDarwin) {
    # Passwordless sudo for deploy-rs activation (agentic deployments)
    security.sudo.extraRules = [
      {
        users = [ cfg.user ];
        commands = [
          { command = "ALL"; options = [ "NOPASSWD" ]; }
        ];
      }
    ];
  };
}
