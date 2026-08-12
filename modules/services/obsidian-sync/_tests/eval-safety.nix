# Pure Nix/build test: keep hybrid Sync topology and stop actions enforced.
{
  nixosConfig,
  darwinConfig,
  pkgs,
}:
let
  inherit (builtins) elem filter length;
  inherit (pkgs.lib) any;
  inherit (pkgs.lib.strings) hasInfix;

  nuc = nixosConfig.config;
  mac = darwinConfig.config;
  sync = nuc.modules.services.obsidian-sync;
  preStart = nuc.systemd.services.obsidian-sync.serviceConfig.ExecStartPre;
  nucGuard = nuc.systemd.services.obsidian-sync-guard.serviceConfig.ExecStart;
  macGuard = mac.launchd.user.agents.obsidian-sync-guard.command;
  macHostSource = builtins.readFile ../../../../hosts/mactraitorpro/default.nix;
  nucDirtTimer = nuc.systemd.timers.obsidian-vault-git-dirt-check.timerConfig;
  macDirtTimer =
    mac.launchd.user.agents.obsidian-vault-git-dirt-check.serviceConfig.StartCalendarInterval;
  openwikiDailyAudit = mac.launchd.user.agents.openwiki-daily-thread-audit;
  dirtCheck = pkgs.callPackage ../../../../packages/obsidian-vault-git-dirt-check { };

  requiredExclusions = [
    ".git"
    ".agents"
    ".env"
    ".envrc"
    "OLD_VAULT"
    "01_Projects"
    "02_Areas"
    "03_Resources"
    "04_Archive"
    "05_Attachments"
    "06_Archive"
    "06_Metadata"
    "02_Projects/Eve-Healthcheck-Remediator-Spike/node_modules"
  ];

  assertions = [
    {
      test = sync.enable && sync.safety.enable;
      msg = "NUC Headless Sync and its safety guard must be enabled";
    }
    {
      test = !(mac.modules.services.obsidian-sync.enable or false);
      msg = "Mac Headless Sync must remain disabled";
    }
    {
      test = builtins.all (path: elem path sync.excludedFolders) requiredExclusions;
      msg = "NUC must contain the shared exclusion subset";
    }
    {
      test = any (entry: hasInfix "obsidian-sync-safety-check" (toString entry)) preStart;
      msg = "NUC Headless must run the safety checker before start";
    }
    {
      test = nuc.systemd.timers.obsidian-sync-guard.timerConfig.OnUnitActiveSec == "30s";
      msg = "NUC guard must run every 30 seconds";
    }
    {
      test = hasInfix "obsidian-sync-safety-stop" (toString nucGuard);
      msg = "NUC guard must use the stop-and-alert wrapper";
    }
    {
      test = hasInfix "obsidian-desktop-sync-guard" (toString macGuard);
      msg = "Mac Desktop guard must be installed";
    }
    {
      test = hasInfix "Obsidian closed to protect your vault" macHostSource;
      msg = "Mac guard notification must explain why Obsidian closed";
    }
    {
      test = hasInfix "Desktop Sync paused by safety guard" macHostSource;
      msg = "Mac guard notification must identify Desktop Sync as paused";
    }
    {
      test = hasInfix ".violations[0].message" macHostSource;
      msg = "Mac guard notification must include the concrete safety violation";
    }
    {
      test = mac.launchd.user.agents.obsidian-sync-guard.serviceConfig.StartInterval == 30;
      msg = "Mac guard must run every 30 seconds";
    }
    {
      test = nucDirtTimer.OnCalendar == "*-*-* 09,21:00:00";
      msg = "NUC Git dirt audit must run at 09:00 and 21:00";
    }
    {
      test =
        map (entry: { inherit (entry) Hour Minute; }) macDirtTimer == [
          {
            Hour = 9;
            Minute = 0;
          }
          {
            Hour = 21;
            Minute = 0;
          }
        ];
      msg = "Mac Git dirt audit must run at 09:00 and 21:00";
    }
    {
      test = hasInfix "openwiki-daily-thread-audit" (toString openwikiDailyAudit.command);
      msg = "Mac must run the OpenWiki daily audit in its existing Codex thread";
    }
    {
      test =
        {
          inherit (openwikiDailyAudit.serviceConfig.StartCalendarInterval) Hour Minute;
        } == {
          Hour = 3;
          Minute = 0;
        };
      msg = "OpenWiki thread audit must run daily at 03:00 local time";
    }
  ];

  failures = filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "obsidian-sync-safety-assertions"
  {
    nativeBuildInputs = [ pkgs.git ];
    passthru = { inherit assertions failures; };
  }
  ''
    if [ ${toString (length failures)} -ne 0 ]; then
      echo "${toString (length failures)} Obsidian Sync structural assertions failed" >&2
      exit 1
    fi
    ${../../../../packages/obsidian-vault-git-dirt-check/git-dirt-check.test.sh} ${dirtCheck}/bin/obsidian-vault-git-dirt-check
    mkdir -p "$out"
    echo "All Obsidian Sync safety assertions passed." > "$out/result"
  ''
