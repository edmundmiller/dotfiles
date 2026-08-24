# Pure Nix eval: the first rollout stage must keep exactly one locked-down
# response lane per Buzz identity while Scintillate is the native canary.
{
  nixosConfig,
  pkgs,
  buzzBindings,
}:
let
  cfg = nixosConfig.config;
  inherit (pkgs) lib;
  publicProfiles = builtins.attrNames buzzBindings.profiles;
  expectedPublicProfiles = [
    "amosburton"
    "anne"
    "betty"
    "finn"
    "scintillate"
  ];
  expectedAcpProfiles = [
    "amosburton"
    "anne"
    "betty"
    "finn"
  ];
  fleetPackage = cfg.services.hermes-agent.package;
  gatewayName = profile: "hermes-gateway-${profile}";
  acpName = profile: "buzz-hermes-${profile}";
  presenceName = profile: "buzz-presence-${profile}";
  gatewayEnabled = profile: (cfg.systemd.services.${gatewayName profile}.enable or false);
  hasAcp = profile: builtins.hasAttr (acpName profile) cfg.systemd.services;
  hasPresence = profile: builtins.hasAttr (presenceName profile) cfg.systemd.services;
  nativeProfiles = builtins.filter gatewayEnabled publicProfiles;
  acpProfiles = builtins.filter hasAcp publicProfiles;

  acpAssertions =
    profile:
    let
      binding = buzzBindings.profiles.${profile};
      service = cfg.systemd.services.${acpName profile};
      profileConfig = cfg.services.hermes-agent.profiles.${profile};
      inherit (service) environment;
      inherit (service) serviceConfig;
      stateDir = "/var/lib/hermes-${profile}";
      mountSources = builtins.attrNames profileConfig.hostPathMounts;
      allowMoni = binding.respondTo == "allowlist";
      translateContainerPath =
        value:
        let
          mountCandidate =
            if lib.hasPrefix "/home/hermes/" value then lib.removePrefix "/home/hermes" value else value;
          mountValue = lib.foldl' (
            resolved: source:
            let
              target = profileConfig.hostPathMounts.${source};
            in
            if resolved == target || lib.hasPrefix "${target}/" resolved then
              source + lib.removePrefix target resolved
            else
              resolved
          ) mountCandidate mountSources;
        in
        if mountValue != mountCandidate then
          mountValue
        else if value == "/data" || lib.hasPrefix "/data/" value then
          stateDir + lib.removePrefix "/data" value
        else if value == "/home/hermes" || lib.hasPrefix "/home/hermes/" value then
          "${stateDir}/home" + lib.removePrefix "/home/hermes" value
        else
          value;
      profileEnvironmentNames = builtins.attrNames profileConfig.environment;
      dedicatedIdentity = cfg.age.secrets."buzz-hermes-${profile}-agent-env".path;
    in
    [
      {
        test = !gatewayEnabled profile && !hasPresence profile && hasAcp profile;
        msg = "${profile}: staged fallback must own the identity without a native gateway or presence duplicate.";
      }
      {
        test =
          environment.BUZZ_ACP_AGENT_COMMAND == "${fleetPackage}/bin/hermes"
          && environment.BUZZ_ACP_AGENT_ARGS == "acp"
          && environment.BUZZ_ACP_PERMISSION_MODE == "dont-ask"
          && environment.HERMES_PROFILE == profile
          && environment.HOME == stateDir
          && environment.HERMES_HOME == "${stateDir}/.hermes"
          && environment.HERMES_REAL_HOME == stateDir
          && environment.MESSAGING_CWD == "${stateDir}/workspace";
        msg = "${profile}: staged ACP must use the shared package, host paths, and permission-denying mode.";
      }
      {
        test =
          environment.BUZZ_ACP_SUBSCRIBE == "config"
          && lib.hasInfix "buzz-acp-${profile}.toml" (toString environment.BUZZ_ACP_CONFIG)
          && environment.BUZZ_ACP_AGENT_OWNER == buzzBindings.identities.edmund.pubkey
          && environment.BUZZ_ACP_RESPOND_TO == binding.respondTo
          &&
            environment.BUZZ_ACP_ALLOWED_RESPOND_TO
            == (if allowMoni then "owner-only,allowlist" else "owner-only")
          && (
            if allowMoni then
              environment.BUZZ_ACP_RESPOND_TO_ALLOWLIST == buzzBindings.moniPubkey
            else
              !(environment ? BUZZ_ACP_RESPOND_TO_ALLOWLIST)
          )
          && !(environment ? BUZZ_ACP_RELAY_OBSERVER);
        msg = "${profile}: staged ACP routing must preserve the canonical owner, allowlist, and subscription boundary.";
      }
      {
        test =
          serviceConfig.EnvironmentFile == profileConfig.environmentFiles
          && builtins.elem dedicatedIdentity profileConfig.environmentFiles
          && serviceConfig.WorkingDirectory == "${stateDir}/workspace"
          && serviceConfig.BindPaths == lib.unique ([ stateDir ] ++ mountSources);
        msg = "${profile}: staged ACP must reuse its dedicated encrypted identity and exact host mounts.";
      }
      {
        test = lib.all (
          name: environment.${name} == translateContainerPath profileConfig.environment.${name}
        ) profileEnvironmentNames;
        msg = "${profile}: staged ACP must translate every container-only profile path to its host equivalent.";
      }
      {
        test =
          serviceConfig.ProtectSystem == "strict"
          && serviceConfig.ProtectHome == "tmpfs"
          && serviceConfig.NoNewPrivileges
          && serviceConfig.PrivateTmp
          && serviceConfig.PrivateDevices
          &&
            serviceConfig.InaccessiblePaths == [
              "-/run/docker.sock"
              "-/run/podman/podman.sock"
            ]
          && serviceConfig.SystemCallArchitectures == "native";
        msg = "${profile}: staged ACP fallback must retain its hardened host boundary.";
      }
    ];

  assertions = [
    {
      test = publicProfiles == expectedPublicProfiles;
      msg = "Staged coverage must include exactly the five public Buzz identities.";
    }
    {
      test = nativeProfiles == [ "scintillate" ] && acpProfiles == expectedAcpProfiles;
      msg = "The first rollout stage must select only Scintillate and retain four ACP fallbacks.";
    }
    {
      test =
        lib.all (profile: gatewayEnabled profile != hasAcp profile) publicProfiles
        && lib.all (profile: hasPresence profile == gatewayEnabled profile) publicProfiles;
      msg = "Every staged identity must have exactly one response transport and presence only with native Buzz.";
    }
    {
      test =
        hasPresence "scintillate"
        && !(hasAcp "scintillate")
        && cfg.systemd.services.hermes-gateway-scintillate.enable
        && cfg.systemd.services.buzz-presence-scintillate.environment.BUZZ_ACP_RESPOND_TO == "nobody";
      msg = "Scintillate must be a native canary with a silent presence-only companion.";
    }
    {
      test =
        !(builtins.hasAttr (acpName "orchestrator") cfg.systemd.services)
        && !(builtins.hasAttr (presenceName "orchestrator") cfg.systemd.services);
      msg = "Orchestrator must remain internal during staged rollout.";
    }
  ]
  ++ builtins.concatMap acpAssertions acpProfiles;

  failures = builtins.filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "nuc-buzz-hermes-staged-runtime" { } ''
  if [ ${toString (builtins.length failures)} -ne 0 ]; then
    cat >&2 <<'EOF'
  Buzz/Hermes staged runtime assertions failed:
  ${builtins.concatStringsSep "\n" (map (failure: "- ${failure.msg}") failures)}
  EOF
    exit 1
  fi

  touch "$out"
''
