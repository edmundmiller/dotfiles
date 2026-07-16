# Regression test: capture Radar's missing blogwatcher runtime dependency.
{ nixosConfig, pkgs }:
let
  service = nixosConfig.config.systemd.services.hermes-radar-cron-tick;
  pathStrings = map (pkg: builtins.unsafeDiscardStringContext (toString pkg)) service.path;
  hasBlogwatcher = builtins.any (pkg: pkgs.lib.hasInfix "blogwatcher-cli" pkg) pathStrings;
in
pkgs.runCommand "nuc-radar-cron-runtime-regression" { } ''
  if [ "${if hasBlogwatcher then "1" else "0"}" -ne 0 ]; then
    echo "Regression fixture expected Radar blogwatcher-cli to be missing." >&2
    exit 1
  fi
  touch "$out"
''
