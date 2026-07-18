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

  requiredExclusions = [
    ".git"
    ".agents"
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
      test = mac.launchd.user.agents.obsidian-sync-guard.serviceConfig.StartInterval == 30;
      msg = "Mac guard must run every 30 seconds";
    }
  ];

  failures = filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "obsidian-sync-safety-assertions"
  {
    passthru = { inherit assertions failures; };
  }
  ''
    if [ ${toString (length failures)} -ne 0 ]; then
      echo "${toString (length failures)} Obsidian Sync structural assertions failed" >&2
      exit 1
    fi
    mkdir -p "$out"
    echo "All Obsidian Sync safety assertions passed." > "$out/result"
  ''
