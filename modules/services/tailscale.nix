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

    # NixOS owns tailscaled. On Darwin the official Tailscale.app / Network
    # Extension owns the tunnel; starting a second logged-out daemon leaves
    # the GUI stuck Connecting and the CLI returning CLIError 1.

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

    # macOS: official Tailscale.app owns the tunnel. Homebrew keeps the
    # standalone app current; Nix only adds MagicDNS resolver + aliases.
    (optionalAttrs isDarwin {
      homebrew.casks = [ "tailscale-app" ];
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
