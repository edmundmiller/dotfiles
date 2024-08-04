{
  config,
  options,
  lib,
  my,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.tailscale;
in
{
  options.modules.services.tailscale = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    services.tailscale.enable = true;
    services.tailscale.openFirewall = true;

    # MagicDNS
    networking.nameservers = [
      "100.100.100.100"
      "8.8.8.8"
      "1.1.1.1"
    ];
    networking.search = [ "cinnamon-rooster.ts.net" ];

    environment.shellAliases = {
      ts = "tailscale";
      tsu = "tailscale up";
      tsd = "tailscale down";
    };
  };
}
