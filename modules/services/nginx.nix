{
  config,
  options,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.nginx;
in
{
  options.modules.services.nginx = {
    enable = mkBoolOpt false;
  };

  # NixOS-only service
  config = optionalAttrs (!isDarwin) (mkIf cfg.enable {
    services.nginx = {
      enable = true;

      # Use recommended settings
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
  });
}
