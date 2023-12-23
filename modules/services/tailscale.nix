{
  config,
  options,
  lib,
  my,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.services.tailscale;
in {
  options.modules.services.tailscale = {enable = mkBoolOpt false;};

  config = mkIf cfg.enable {
    services.tailscale.enable = true;

    networking.firewall = {
      allowedTCPPorts = [41641];
      allowedUDPPorts = [41641];
      checkReversePath = "loose";
    };

    # MagicDNS
    networking.nameservers = ["100.100.100.100" "8.8.8.8" "1.1.1.1"];
    networking.search = ["tailff8ca.ts.net"];

    environment.shellAliases = {
      ts = "tailscale";
      tsu = "tailscale up";
      tsd = "tailscale down";
    };
  };
}
