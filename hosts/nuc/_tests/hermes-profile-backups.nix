{ nixosConfig, pkgs }:
let
  inherit (builtins)
    all
    attrNames
    attrValues
    concatStringsSep
    elem
    filter
    length
    map
    ;

  cfg = nixosConfig.config;
  backup = cfg.services.restic.backups.hermes-profile-state or { };
  dailyBackup = cfg.services.restic.backups.daily or { };
  nucR2Backups = filter (
    candidate:
    (candidate.environmentFile or null) == (dailyBackup.environmentFile or null)
    && (candidate.pruneOpts or [ ]) != [ ]
  ) (attrValues cfg.services.restic.backups);
  profiles = cfg.services.hermes-agent.profiles;
  expectedPaths = map (profile: "${profiles.${profile}.stateDir}/.hermes") (attrNames profiles);
  timer = backup.timerConfig or { };

  assertions = [
    {
      test = expectedPaths != [ ] && (backup.paths or [ ]) == expectedPaths;
      msg = "Hermes profile backup must cover every configured profile home";
    }
    {
      test =
        elem "--tag" (backup.extraBackupArgs or [ ])
        && elem "hermes-profile-state" (backup.extraBackupArgs or [ ]);
      msg = "Hermes profile backup must carry its restore/diff tag";
    }
    {
      test = (timer.OnCalendar or "") == "*-*-* *:15:00";
      msg = "Hermes profile backup must run hourly";
    }
    {
      test =
        (backup.pruneOpts or [ ]) == [
          "--keep-within 24h"
          "--keep-daily 7"
          "--keep-weekly 5"
          "--keep-monthly 12"
        ];
      msg = "Hermes profile backup retention must preserve short-term rollback points and long-term history";
    }
    {
      test = all (candidate: (candidate.pruneOpts or [ ]) == backup.pruneOpts) nucR2Backups;
      msg = "Every pruner sharing nuc-restic must preserve the hourly Hermes restore points";
    }
  ];

  failures = filter (assertion: !assertion.test) assertions;
  resultText =
    if failures == [ ] then
      "All ${toString (length assertions)} Hermes profile backup assertions passed."
    else
      concatStringsSep "\n" (
        [
          "${toString (length failures)}/${toString (length assertions)} Hermes profile backup assertions failed:"
        ]
        ++ map (assertion: "  FAIL: ${assertion.msg}") failures
      );
in
pkgs.runCommand "hermes-profile-backup-assertions"
  {
    passthru = { inherit assertions failures; };
  }
  ''
    ${
      if failures == [ ] then
        ''
          echo "${resultText}"
          mkdir -p "$out"
          echo "${resultText}" > "$out/result"
        ''
      else
        ''
          echo "${resultText}" >&2
          exit 1
        ''
    }
  ''
