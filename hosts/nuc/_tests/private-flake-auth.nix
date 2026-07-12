{ nixosConfig, pkgs }:
let
  cfg = nixosConfig.config;
  upgradeScript = cfg.systemd.services.nixos-upgrade.script;
  quotedFlakeArgument = pkgs.lib.hasInfix "'--flake github:" upgradeScript;
in
pkgs.runCommand "nuc-private-flake-auth" { } ''
  if [ "${if quotedFlakeArgument then "1" else "0"}" = 1 ]; then
    echo "Private flake URL must reach nixos-rebuild as a separate --flake argument." >&2
    exit 1
  fi
  touch $out
''
