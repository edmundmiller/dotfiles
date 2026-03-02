# Mosh — mobile shell for roaming/intermittent connectivity
# UDP-based, survives WiFi→cellular handoffs, sleep/wake, IP changes
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
  cfg = config.modules.services.mosh;
in
{
  options.modules.services.mosh = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # mosh client available everywhere
      user.packages = [ pkgs.mosh ];
    }

    # NixOS: mosh server + firewall (UDP 60000-61000)
    (optionalAttrs (!isDarwin) {
      programs.mosh = {
        enable = true;
        openFirewall = true;
      };
    })
  ]);
}
