{ nixosConfig, pkgs }:
let
  cfg = nixosConfig.config;
  upgradeScript = cfg.systemd.services.nixos-upgrade.script;
  quotedFlakeArgument = pkgs.lib.hasInfix "'--flake github:" upgradeScript;
  strictXfail = true;
in
pkgs.runCommand "nuc-private-flake-auth" { } ''
  if [ "${if strictXfail && quotedFlakeArgument then "1" else "0"}" != 1 ]; then
    echo "Strict expected failure changed: update the private flake auth regression assertion." >&2
    exit 1
  fi
  touch $out
''
