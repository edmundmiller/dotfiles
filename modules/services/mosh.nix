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
      # Keep mosh-server on the system profile so Moshi's non-interactive SSH
      # bootstrap can find it without relying on login shell PATH setup.
      environment.systemPackages = [ pkgs.mosh ];

      # mosh client available in the user profile too.
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
