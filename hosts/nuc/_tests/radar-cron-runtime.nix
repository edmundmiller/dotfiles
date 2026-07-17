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

  # Expected failure: Hermes builds its terminal snapshot through a login
  # shell, so service.path alone is insufficient. Fail on unexpected pass
  # until the host system profile provides the declared runtime too.
  if [ "${if hasShellBlogwatcher || hasShellRtk then "1" else "0"}" -ne 0 ]; then
    echo "Unexpected pass: move the terminal-shell assertion out of expected failure." >&2
    exit 1
  fi
  touch "$out"
''
