# Regression contract for the 2026-07 Betty scheduler outage.
{ nixosConfig, pkgs }:
let
  cfg = nixosConfig.config;
  bettyService = cfg.systemd.services.hermes-betty-cron-tick;
  bettyTimer = cfg.systemd.timers.hermes-betty-cron-tick;
  bettyGateway = cfg.systemd.services.hermes-gateway-betty;

  inherit (pkgs.lib) concatStringsSep hasInfix;

  assertions = [
    {
      test = !bettyGateway.enable;
      msg = "Betty's interactive gateway must remain disabled for isolated cron execution.";
    }
    {
      test = bettyService.serviceConfig.Type == "oneshot";
      msg = "Betty cron executor must be a oneshot service.";
    }
    {
      test = bettyService.serviceConfig.User == "emiller";
      msg = "Betty cron executor must use the profile owner.";
    }
    {
      test = hasInfix "betty-hermes cron tick" (toString bettyService.serviceConfig.ExecStart);
      msg = "Betty cron executor must sync canonical jobs through the Betty launcher before ticking.";
    }
    {
      test = bettyTimer.wantedBy == [ "timers.target" ];
      msg = "Betty cron timer must start with timers.target.";
    }
    {
      test = bettyTimer.timerConfig.OnUnitActiveSec == "5min";
      msg = "Betty cron timer must tick every five minutes.";
    }
    {
      test = bettyTimer.timerConfig.Unit == "hermes-betty-cron-tick.service";
      msg = "Betty cron timer must target its isolated executor.";
    }
    {
      test = hasInfix "HERMES_HOME=/var/lib/hermes-betty/.hermes" (concatStringsSep " " bettyService.serviceConfig.Environment);
      msg = "Betty cron executor must target Betty's isolated Hermes home.";
    }
    {
      test = hasInfix "/var/lib/hermes-betty" (concatStringsSep " " bettyService.serviceConfig.ReadWritePaths);
      msg = "Betty cron executor must be able to update Betty's cron state.";
    }
  ];

  failures = builtins.filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "nuc-hermes-cron-executors" { } ''
  if [ ${toString (builtins.length failures)} -ne 0 ]; then
    cat >&2 <<'EOF'
  NUC Hermes cron executor assertions failed:
  ${pkgs.lib.concatStringsSep "\n" (map (failure: "- ${failure.msg}") failures)}
  EOF
    exit 1
  fi

  mkdir -p "$out"
  echo "NUC Hermes cron executor assertions passed" > "$out/result"
''
