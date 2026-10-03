{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.mo;
  diskReport = pkgs.writeShellApplication {
    name = "mole-disk-report";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
    ];
    text = ''
      export PATH="${config.user.home}/.local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
      export MOLE_REPORT_AMP_SETTINGS=${../../../config/mole/report-amp-settings.json}
      export MOLE_REPORT_NOTIFY=1
      ${builtins.readFile ../../../config/mole/disk-reclaim-report.sh}
    '';
  };
in
{
  options.modules.shell.mo = with types; {
    enable = mkBoolOpt false;
    diskReport.enable = mkBoolOpt false;
    purgePaths = mkOpt' (listOf str) [ ] ''
      Project scan directories for `mo purge`, written to
      $XDG_CONFIG_HOME/mole/purge_paths (one path per line).

      This file is Nix-managed (a read-only store symlink), so edit this
      option and rebuild rather than running `mo purge --paths`.
    '';
  };

  config = mkIf cfg.enable (
    mkMerge (
      [
        {
          home.configFile = mkIf (cfg.purgePaths != [ ]) {
            "mole/purge_paths".text = concatMapStringsSep "\n" (p: p) cfg.purgePaths + "\n";
          };
        }
      ]
      ++ optionals isDarwin [
        {
          # Mole (mo) is distributed via Homebrew only.
          homebrew.brews = [ "mole" ];
          user.packages = optionals cfg.diskReport.enable [ diskReport ];
          launchd.user.agents = optionalAttrs cfg.diskReport.enable {
            mole-disk-report = {
              command = "${diskReport}/bin/mole-disk-report";
              serviceConfig = {
                # Sunday morning in the host's local timezone. No cleanup.
                StartCalendarInterval = {
                  Weekday = 0;
                  Hour = 9;
                  Minute = 0;
                };
                ProcessType = "Background";
                LowPriorityIO = true;
                StandardOutPath = "${config.user.home}/Library/Logs/mole-disk-report.log";
                StandardErrorPath = "${config.user.home}/Library/Logs/mole-disk-report.err.log";
                EnvironmentVariables.HOME = config.user.home;
                WorkingDirectory = config.user.home;
              };
            };
          };
        }
      ]
    )
  );
}
