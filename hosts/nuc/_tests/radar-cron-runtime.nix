# Radar's cron runtime must provide blogwatcher-cli to digest jobs.
{ nixosConfig, pkgs }:
let
  service = nixosConfig.config.systemd.services.hermes-radar-cron-tick;
  pathStrings = map (pkg: builtins.unsafeDiscardStringContext (toString pkg)) service.path;
  hasBlogwatcher = builtins.any (pkg: pkgs.lib.hasInfix "blogwatcher-cli" pkg) pathStrings;
in
pkgs.runCommand "nuc-radar-cron-runtime-regression" { } ''
  if [ "${if hasBlogwatcher then "1" else "0"}" -ne 1 ]; then
    echo "Radar cron runtime must include blogwatcher-cli." >&2
    exit 1
  fi
  touch "$out"
''
