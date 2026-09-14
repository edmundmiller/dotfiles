{ nixosConfig, pkgs }:
let
  cfg = nixosConfig.config;
  service = cfg.systemd.services.hermes-scintillate-desktop-dashboard;
  tailscaleService = cfg.systemd.services.hermes-tailscale-serve;
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
    && pkgs.lib.hasInfix "--volume ${stateDir}:/data" preStart
    && pkgs.lib.hasInfix "--volume ${stateDir}/home:/home/hermes" preStart
    && pkgs.lib.hasInfix "--env HERMES_HOME=/data/.hermes" preStart
    && pkgs.lib.hasInfix "--env HERMES_PROFILE=${profile}" preStart
    && pkgs.lib.hasInfix "/data/current-package/bin/hermes gateway run" preStart
  ) gatewayProfiles;
  packageIdentityMatches =
    (hermesPackage.passthru.hermesVersion or null) == "0.21.0"
    && (hermesPackage.passthru.hermesRelease or null) == "v2026.8.31";
  dashboardStart = toString service.serviceConfig.ExecStart;
  expectedDashboardExec = "${hermesPackage}/bin/hermes dashboard";
  caduSetup = builtins.head service.serviceConfig.ExecStartPre;
  yamlPython = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
  assertions = [
    {
      test = builtins.all (
        profile:
        let
          enabled = cfg.services.hermes-agent.profiles.${profile}.settings.plugins.enabled;
        in
        builtins.all (name: builtins.elem name enabled) [
          "cadu-rich-cards"
          "cadu-device"
          "cadu-secrets-vault"
          "hermes-browser-stream"
          "hermes-push"
          "evo"
          "rtk-rewrite"
          "cronalytics"
        ]
      ) gatewayProfiles;
      msg = "Every rendered gateway must enable Cadu plugins without dropping required runtime plugins.";
    }
    {
      test = builtins.elem "photon-platform" cfg.services.hermes-agent.profiles.betty.settings.plugins.enabled;
      msg = "Cadu enablement must preserve Betty's canonical Photon plugin.";
    }
    {
      test = service.enable;
      msg = "Scintillate's Desktop dashboard must remain enabled so auto-upgrades do not mask it.";
    }
    {
      test = service.restartIfChanged;
      msg = "The Hermes Desktop dashboard must restart when its plugin capability boundary changes.";
    }
    {
      test = !builtins.elem pkgs.tailscale service.path;
      msg = "The Hermes Desktop dashboard must not expose the unrestricted host Tailscale CLI to plugins.";
    }
    {
      test = builtins.any (
        package: pkgs.lib.hasInfix "hermes-tailscale-cli" (builtins.baseNameOf (toString package))
      ) service.path;
      msg = "The Hermes Desktop dashboard must expose only the restricted Tailscale plugin CLI.";
    }
    {
      test = builtins.elem "multi-user.target" service.wantedBy;
      msg = "Scintillate's Desktop dashboard must start from multi-user.target after every NUC activation.";
    }
    {
      test =
        tailscaleService.enable
        && builtins.elem "multi-user.target" tailscaleService.wantedBy
        && builtins.elem "hermes-scintillate-desktop-dashboard.service" tailscaleService.wants
        && builtins.elem "tailscaled.service" tailscaleService.after;
      msg = "The Hermes Tailscale service must start with the dashboard after Tailscale is available.";
    }
    {
      test = pkgs.lib.hasInfix "serve --bg --service=svc:hermes --https=443 http://127.0.0.1:9121" tailscaleService.serviceConfig.ExecStart;
      msg = "The Hermes HTTPS service must proxy to the Desktop dashboard on 9121, not the retired WebUI on 8787.";
    }
    {
      test = packageIdentityMatches;
      msg = "Every NUC Hermes consumer must use the shared Hermes v0.21.0 (2026.8.31) package.";
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
    inherit dashboardStart expectedDashboardExec caduSetup;
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

    # Exercise the deployed merge, including repeat starts and absent plugins.
    mkdir -p home/plugins/cadu-rich-cards
    touch home/plugins/cadu-rich-cards/plugin.yaml
    printf '%s\n' 'model: {default: keep-me}' 'plugins: {enabled: [existing-plugin], disabled: [blocked-plugin]}' > home/config.yaml
    setup_script="''${caduSetup%% *}"
    "$setup_script" "$PWD/home" cadu-rich-cards missing-plugin
    "$setup_script" "$PWD/home" cadu-rich-cards missing-plugin
    ${yamlPython}/bin/python3 - <<'PY'
    from pathlib import Path
    import yaml
    config = yaml.safe_load(Path("home/config.yaml").read_text())
    assert config == {
        "model": {"default": "keep-me"},
        "plugins": {
            "enabled": ["existing-plugin", "cadu-rich-cards"],
            "disabled": ["blocked-plugin"],
        },
    }, config
    assert Path("home/config.yaml").stat().st_mode & 0o777 == 0o600
    PY

    touch "$out"
  ''
