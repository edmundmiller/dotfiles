# Radar's cron runtime must provide blogwatcher-cli to digest jobs.
{ nixosConfig, pkgs }:
let
  service = nixosConfig.config.systemd.services.hermes-radar-cron-tick;
  pathStrings = map (pkg: builtins.unsafeDiscardStringContext (toString pkg)) service.path;
  systemPackageStrings = map (pkg: builtins.unsafeDiscardStringContext (toString pkg)) nixosConfig.config.environment.systemPackages;
  hasBlogwatcher = builtins.any (pkg: pkgs.lib.hasInfix "blogwatcher-cli" pkg) pathStrings;
  hasShellBlogwatcher = builtins.any (pkg: pkgs.lib.hasInfix "blogwatcher-cli" pkg) systemPackageStrings;
  hasShellRtk = builtins.any (pkg: pkgs.lib.hasInfix "rtk-" pkg) systemPackageStrings;
in
pkgs.runCommand "nuc-radar-cron-runtime-regression" { } ''
  if [ "${if hasBlogwatcher then "1" else "0"}" -ne 1 ]; then
    echo "Radar cron runtime must include blogwatcher-cli." >&2
    exit 1
  fi

  # Hermes builds its terminal snapshot through a login shell, so service.path
  # alone is insufficient. Both declared runtimes must be in the system profile.
  if [ "${if hasShellBlogwatcher && hasShellRtk then "1" else "0"}" -ne 1 ]; then
    echo "Radar terminal login shell must resolve blogwatcher-cli and rtk." >&2
    exit 1
  fi
  touch "$out"
''
