# Pure Nix eval: Darwin must not start a competing Nix tailscaled.
# Official Tailscale.app is declared via Homebrew, not Nix pkgs.tailscale
# and not the Homebrew tailscale formula (that ships tailscaled).
{
  darwinConfig,
  pkgs,
}:
let
  inherit (builtins)
    any
    elem
    filter
    isAttrs
    length
    ;

  mac = darwinConfig.config;
  casks = mac.homebrew.casks or [ ];
  brews = mac.homebrew.brews or [ ];
  itemName = item: if isAttrs item then (item.name or "") else item;
  hasCask = name: any (cask: itemName cask == name) casks;
  hasBrew = name: any (brew: itemName brew == name) brews;

  assertions = [
    {
      test = mac.modules.services.tailscale.enable or false;
      msg = "MacTraitor-Pro must keep Tailscale aliases and the MagicDNS resolver";
    }
    {
      test = !(mac.services.tailscale.enable or false);
      msg = "MacTraitor-Pro must not enable Nix tailscaled; Tailscale.app owns the tunnel";
    }
    {
      test = !(mac.launchd.daemons ? tailscaled);
      msg = "MacTraitor-Pro must not install com.tailscale.tailscaled";
    }
    {
      test = hasCask "tailscale-app";
      msg = "MacTraitor-Pro must declare the official Homebrew tailscale-app cask";
    }
    {
      test = !(hasCask "tailscale");
      msg = "MacTraitor-Pro must not declare the CLI-only Homebrew tailscale cask";
    }
    {
      test = !(hasBrew "tailscale");
      msg = "MacTraitor-Pro must not declare the Homebrew tailscale formula";
    }
    {
      test = !(elem pkgs.tailscale (mac.environment.systemPackages or [ ]));
      msg = "MacTraitor-Pro must not install Nix pkgs.tailscale; Tailscale.app owns the CLI";
    }
  ];

  failures = filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "darwin-tailscale-app-owner-assertions"
  {
    passthru = {
      inherit assertions failures;
    };
  }
  ''
    if [ ${toString (length failures)} -ne 0 ]; then
      echo "${toString (length failures)} Darwin Tailscale ownership assertions failed" >&2
      exit 1
    fi
    mkdir -p "$out"
    echo "All Darwin Tailscale ownership assertions passed." > "$out/result"
  ''
