# Pure Nix/build test: keep Screen Time archival private, weekly, and R2-scoped.
{
  darwinConfig,
  pkgs,
}:
let
  inherit (builtins) filter length;
  inherit (pkgs.lib) any;
  inherit (pkgs.lib.strings) hasInfix;

  mac = darwinConfig.config;
  agent = mac.launchd.user.agents.screentime-backup;
  service = agent.serviceConfig;
  arguments = service.ProgramArguments;

  assertions = [
    {
      test = any (package: hasInfix "screentime-backup" (toString package)) (
        mac.environment.systemPackages or [ ]
      );
      msg = "Screen Time backup CLI must be available for manual archive and recovery checks";
    }
    {
      test = hasInfix "/bin/screentime-backup" service.Program;
      msg = "Screen Time backup must use the packaged CLI";
    }
    {
      test = builtins.elem "run" arguments;
      msg = "Screen Time LaunchAgent must execute the full archive and backup path";
    }
    {
      test = builtins.elem "${mac.user.home}/Library/Application Support/Knowledge/knowledgeC.db" arguments;
      msg = "Screen Time LaunchAgent must read the local knowledgeC database";
    }
    {
      test = builtins.elem "${mac.user.home}/.local/state/screentime/history.sqlite" arguments;
      msg = "Screen Time archive must stay outside the vault and Git";
    }
    {
      test = builtins.elem "s3:https://57398029d3d0add95bdad89deaa41864.r2.cloudflarestorage.com/screentime-backups" arguments;
      msg = "Screen Time backup must target only the dedicated private R2 bucket";
    }
    {
      test =
        {
          inherit (service.StartCalendarInterval) Weekday Hour Minute;
        } == {
          Weekday = 0;
          Hour = 23;
          Minute = 55;
        };
      msg = "Screen Time backup must run Sunday at 23:55 local time";
    }
    {
      test = service.RunAtLoad != true;
      msg = "Screen Time backup must not run before credentials are provisioned";
    }
    {
      test = service.StandardOutPath == "${mac.user.home}/Library/Logs/screentime-backup.log";
      msg = "Screen Time backup stdout must use the user log directory";
    }
    {
      test = service.StandardErrorPath == "${mac.user.home}/Library/Logs/screentime-backup.err.log";
      msg = "Screen Time backup stderr must use the user log directory";
    }
  ];

  failures = filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "screentime-backup-darwin-assertions"
  {
    passthru = { inherit assertions failures; };
  }
  ''
    if [ ${toString (length failures)} -ne 0 ]; then
      echo "${toString (length failures)} Screen Time backup assertions failed" >&2
      exit 1
    fi
    mkdir -p "$out"
    echo "All Screen Time backup Darwin assertions passed." > "$out/result"
  ''
