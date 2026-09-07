# Pure Nix/build test: keep Discrawl DM backups private, daily, and R2-scoped.
{
  darwinConfig,
  pkgs,
}:
let
  inherit (builtins) filter length;
  inherit (pkgs.lib) any;
  inherit (pkgs.lib.strings) hasInfix;

  mac = darwinConfig.config;
  agent = mac.launchd.user.agents.discrawl-backup;
  service = agent.serviceConfig;
  arguments = service.ProgramArguments;

  assertions = [
    {
      test = any (package: hasInfix "discrawl-backup" (toString package)) (
        mac.environment.systemPackages or [ ]
      );
      msg = "Discrawl backup CLI must be available for manual snapshot and recovery checks";
    }
    {
      test = hasInfix "/bin/discrawl-backup" service.Program;
      msg = "Discrawl backup must use the packaged CLI";
    }
    {
      test = builtins.elem "run" arguments;
      msg = "Discrawl LaunchAgent must execute the full snapshot and backup path";
    }
    {
      test = builtins.elem "${mac.user.home}/.local/share/discrawl/discrawl.db" arguments;
      msg = "Discrawl LaunchAgent must read the configured local archive";
    }
    {
      test = builtins.elem "${mac.user.home}/.local/state/discrawl-backup/discrawl.db" arguments;
      msg = "Discrawl snapshot must stay outside the vault and Git";
    }
    {
      test = builtins.elem "s3:https://57398029d3d0add95bdad89deaa41864.r2.cloudflarestorage.com/discrawl-backups" arguments;
      msg = "Discrawl backup must target only the dedicated private R2 bucket";
    }
    {
      test =
        {
          inherit (service.StartCalendarInterval) Hour Minute;
        } == {
          Hour = 23;
          Minute = 45;
        };
      msg = "Discrawl backup must run daily at 23:45 local time";
    }
    {
      test = service.RunAtLoad != true;
      msg = "Discrawl backup must not run before credentials are provisioned";
    }
    {
      test = service.StandardOutPath == "${mac.user.home}/Library/Logs/discrawl-backup.log";
      msg = "Discrawl backup stdout must use the user log directory";
    }
    {
      test = service.StandardErrorPath == "${mac.user.home}/Library/Logs/discrawl-backup.err.log";
      msg = "Discrawl backup stderr must use the user log directory";
    }
  ];

  failures = filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "discrawl-backup-darwin-assertions"
  {
    passthru = { inherit assertions failures; };
  }
  ''
    if [ ${toString (length failures)} -ne 0 ]; then
      echo "${toString (length failures)} Discrawl backup assertions failed" >&2
      exit 1
    fi
    mkdir -p "$out"
    echo "All Discrawl backup Darwin assertions passed." > "$out/result"
  ''
