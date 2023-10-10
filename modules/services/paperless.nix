{
  options,
  config,
  lib,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.services.paperless;
in {
  options.modules.services.paperless = {enable = mkBoolOpt false;};

  config = mkIf cfg.enable {
    services.paperless.enable = true;
    networking.firewall.allowedTCPPorts = [28981];
  };
}
