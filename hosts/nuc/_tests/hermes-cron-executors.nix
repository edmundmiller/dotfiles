# Regression sentinel for the 2026-07 Betty scheduler outage.
#
# Keep this first commit green while proving the observed bug. The fix commit
# flips the sentinel to the intended executor contract.
{ nixosConfig, pkgs }:
let
  cfg = nixosConfig.config;
  hasBettyTimer = builtins.hasAttr "hermes-betty-cron-tick" cfg.systemd.timers;
  bettyGateway = cfg.systemd.services.hermes-gateway-betty;

  assertions = [
    {
      test = !bettyGateway.enable;
      msg = "Betty's interactive gateway must remain disabled for isolated cron execution.";
    }
    {
      test = !hasBettyTimer;
      msg = "Regression sentinel: Betty unexpectedly has a cron executor before the fix.";
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
  echo "NUC Hermes cron executor regression reproduced" > "$out/result"
''
