{ nixosConfig, pkgs }:
let
  cfg = nixosConfig.config;
  service = cfg.systemd.services.hermes-scintillate-desktop-dashboard;
  hermesPackage = cfg.services.hermes-agent.package;
  gatewayProfiles = [
    "amosburton"
    "anne"
    "betty"
    "finn"
    "orchestrator"
    "scintillate"
  ];
  allGatewaysUseSharedPackage = builtins.all (
    profile: builtins.elem hermesPackage (cfg.systemd.services."hermes-gateway-${profile}".path or [ ])
  ) gatewayProfiles;
  packageIdentityMatches =
    (hermesPackage.passthru.hermesVersion or null) == "0.20.5"
    && (hermesPackage.passthru.hermesRelease or null) == "v2026.8.19";
  dashboardUsesSharedPackage =
    builtins.elem hermesPackage (service.path or [ ])
    && pkgs.lib.hasPrefix "${hermesPackage}/bin/hermes dashboard" service.serviceConfig.ExecStart;
  assertions = [
    {
      test = service.enable;
      msg = "Scintillate's Desktop dashboard must remain enabled so auto-upgrades do not mask it.";
    }
    {
      test = builtins.elem "multi-user.target" service.wantedBy;
      msg = "Scintillate's Desktop dashboard must start from multi-user.target after every NUC activation.";
    }
    {
      test = packageIdentityMatches;
      msg = "Every NUC Hermes consumer must use the shared Hermes v0.20.5 (2026.8.19) package.";
    }
    {
      test = allGatewaysUseSharedPackage;
      msg = "All six NUC Hermes gateway profiles must consume the shared Hermes package path.";
    }
    {
      test = dashboardUsesSharedPackage;
      msg = "The Scintillate Desktop dashboard must consume the shared Hermes package path.";
    }
  ];
  failures = builtins.filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "nuc-hermes-dashboard-enabled" { } ''
  if [ ${toString (builtins.length failures)} -ne 0 ]; then
    cat >&2 <<'EOF'
  NUC Hermes Desktop dashboard assertions failed:
  ${builtins.concatStringsSep "\n" (map (failure: "- ${failure.msg}") failures)}
  EOF
    exit 1
  fi

  touch "$out"
''
