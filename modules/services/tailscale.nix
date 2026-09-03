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
      environment.shellAliases = {
        # Note: 'ts' conflicts with 'task sync' alias in modules/shell/zsh/default.nix
        tsc = "tailscale";
        tsu = "tailscale up";
        tsd = "tailscale down";
        tss = "tailscale status";
      };
    }

    (optionalAttrs (!isDarwin) {
      services.tailscale.enable = true;
      services.tailscale.openFirewall = true;
      # Allow user to run `tailscale serve` without sudo for locally managed services
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

    # Tailscale SSH hosting on macOS requires the open-source tailscaled
    # variant. The GUI app must not be installed alongside this daemon.
    (optionalAttrs isDarwin {
      services.tailscale.enable = true;
      environment.etc = {
        "resolver/cinnamon-rooster.ts.net".text = ''
          nameserver 100.100.100.100
          search_order 1
          timeout 2
        '';
      };
    })
  ]);
}
