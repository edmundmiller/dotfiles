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
  hermesPackagePath = builtins.unsafeDiscardStringContext (toString hermesPackage);
  allGatewaysUseSharedPackage = builtins.all (
    profile:
    let
      gatewayService = cfg.systemd.services."hermes-gateway-${profile}";
      preStart = builtins.unsafeDiscardStringContext (gatewayService.preStart or "");
    in
    pkgs.lib.hasInfix hermesPackagePath preStart
  ) gatewayProfiles;
  runtimeOwner = "${cfg.services.hermes-agent.user}:${cfg.services.hermes-agent.group}";
  allContainerIdentityMetadataReadable = builtins.all (
    profile:
    let
      gatewayService = cfg.systemd.services."hermes-gateway-${profile}";
      stateDir = cfg.services.hermes-agent.profiles.${profile}.stateDir;
      preStart = builtins.unsafeDiscardStringContext (gatewayService.preStart or "");
    in
    pkgs.lib.hasInfix "chown ${runtimeOwner} ${stateDir}/.container-identity" preStart
    && pkgs.lib.hasInfix "chmod 0640 ${stateDir}/.container-identity" preStart
    && pkgs.lib.hasInfix "chmod 0600 ${stateDir}/.container-env-identity" preStart
  ) gatewayProfiles;
  packageIdentityMatches =
    (hermesPackage.passthru.hermesVersion or null) == "0.20.5"
    && (hermesPackage.passthru.hermesRelease or null) == "v2026.8.19";
  dashboardStart = toString service.serviceConfig.ExecStart;
  expectedDashboardExec = "${hermesPackage}/bin/hermes dashboard";
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
      test = allContainerIdentityMetadataReadable;
      msg = "All six container profiles must expose non-secret identity metadata to the dashboard owner while keeping env identity private.";
    }
  ];
  failures = builtins.filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "nuc-hermes-dashboard-enabled"
  {
    inherit dashboardStart expectedDashboardExec;
  }
  ''
    if [ ${toString (builtins.length failures)} -ne 0 ]; then
      cat >&2 <<'EOF'
    NUC Hermes Desktop dashboard assertions failed:
    ${builtins.concatStringsSep "\n" (map (failure: "- ${failure.msg}") failures)}
    EOF
      exit 1
    fi

    dashboard_start="''${dashboardStart%% *}"
    if [ ! -x "$dashboard_start" ] || ! grep -Fq -- "$expectedDashboardExec" "$dashboard_start"; then
      echo "Scintillate's Desktop dashboard must execute the shared Hermes package." >&2
      exit 1
    fi

    touch "$out"
  ''
