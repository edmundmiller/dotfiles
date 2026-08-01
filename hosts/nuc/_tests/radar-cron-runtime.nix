# Radar's cron runtime must provide blogwatcher-cli to digest jobs.
{ nixosConfig, pkgs }:
let
  service = nixosConfig.config.systemd.services.hermes-radar-cron-tick;
  pathStrings = map (pkg: builtins.unsafeDiscardStringContext (toString pkg)) service.path;
  systemPackageStrings = map (
    pkg: builtins.unsafeDiscardStringContext (toString pkg)
  ) nixosConfig.config.environment.systemPackages;
  execStartPreStrings = map builtins.toString (service.serviceConfig.ExecStartPre or [ ]);
  hasBlogwatcher = builtins.any (pkg: pkgs.lib.hasInfix "blogwatcher-cli" pkg) pathStrings;
  hasShellBlogwatcher = builtins.any (
    pkg: pkgs.lib.hasInfix "blogwatcher-cli" pkg
  ) systemPackageStrings;
  hasShellRtk = builtins.any (pkg: pkgs.lib.hasInfix "rtk-" pkg) systemPackageStrings;
  repairsStateOwnership = builtins.any (
    command: pkgs.lib.hasInfix "chown -hR emiller:users /var/lib/hermes-radar" command
  ) execStartPreStrings;
  preparesIsolatedVault = builtins.any (
    command: pkgs.lib.hasInfix "radar-vault-prepare" command
  ) execStartPreStrings;
  radarVaultLink =
    nixosConfig.config.modules.services.hermes.agents.radar.workspaceLinks."repos/obsidian-vault";
  radarSecretMaterialization =
    nixosConfig.config.system.activationScripts.hermesRadarSecretsMaterialize.text;
  knownActivationTargetsLiveVault = pkgs.lib.hasInfix ''ln -sfn /home/emiller/obsidian-vault "$HERMES_ENV_HOME/workspace/repos/obsidian-vault"'' radarSecretMaterialization;
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

  # A root-run launcher can leave generated state unreadable to the timer user.
  # Startup must restore the profile's declared owner before materialization.
  if [ "${if repairsStateOwnership then "1" else "0"}" -ne 1 ]; then
    echo "Radar cron startup must repair profile state ownership." >&2
    exit 1
  fi
  if [ "${if preparesIsolatedVault then "1" else "0"}" -ne 1 ]; then
    echo "Radar cron must prepare and publish its isolated vault checkout." >&2
    exit 1
  fi
  if [ ${pkgs.lib.escapeShellArg radarVaultLink} != /var/lib/hermes-radar/.hermes/state/obsidian-vault ]; then
    echo "Radar cron must not write to the live Obsidian Sync checkout." >&2
    exit 1
  fi
  if [ "${if knownActivationTargetsLiveVault then "1" else "0"}" -ne 0 ]; then
    echo "Radar activation must not relink its workspace to the live vault." >&2
    exit 1
  fi
  touch "$out"
''
