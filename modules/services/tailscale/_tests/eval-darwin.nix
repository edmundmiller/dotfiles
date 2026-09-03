# Pure Nix eval: Darwin must use exactly one open-source tailscaled owner.
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
      test = mac.services.tailscale.enable or false;
      msg = "MacTraitor-Pro must enable Nix tailscaled for Tailscale SSH hosting";
    }
    {
      test = mac.launchd.daemons ? tailscaled;
      msg = "MacTraitor-Pro must install the tailscaled launch daemon";
    }
    {
      test = !(hasCask "tailscale-app");
      msg = "MacTraitor-Pro must not declare the competing Tailscale GUI app";
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
      test = elem mac.services.tailscale.package (mac.environment.systemPackages or [ ]);
      msg = "MacTraitor-Pro must install the CLI package that owns tailscaled";
    }
  ];

  failures = filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "darwin-tailscaled-owner-assertions"
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
    echo "All Darwin tailscaled ownership assertions passed." > "$out/result"
  ''
