{
  config,
  lib,
  isDarwin,
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

  config = mkIf cfg.enable (mkMerge [
    {
      services.tailscale.enable = true;

      environment.shellAliases = {
        # Note: 'ts' conflicts with 'task sync' alias in modules/shell/zsh/default.nix
        tsc = "tailscale";
        tsu = "tailscale up";
        tsd = "tailscale down";
        tss = "tailscale status";
      };
    }

    # NixOS-specific networking configuration
    (optionalAttrs (!isDarwin) {
      services.tailscale.openFirewall = true;
      # Allow user to run `tailscale serve` without sudo (for openclaw-gateway etc)
      services.tailscale.extraSetFlags = [ "--operator=${config.user.name}" ];

      # MagicDNS
      services.resolved.enable = true;
      networking.nameservers = [
        "100.100.100.100"
        "8.8.8.8"
        "1.1.1.1"
      ];
      networking.search = [ "cinnamon-rooster.ts.net" ];
    })
  ]);
}
