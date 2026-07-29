# Pure Nix eval: each configured NUC Hermes profile must have an isolated
# Buzz community runtime that preserves its canonical host access boundary.
{
  nixosConfig,
  pkgs,
  buzzBindings,
}:
let
  cfg = nixosConfig.config;
  profiles = builtins.attrNames cfg.modules.services.hermes.agents;
  services = map (profile: cfg.systemd.services."buzz-hermes-${profile}") profiles;
  identityFiles = map (
    service:
    builtins.elemAt service.serviceConfig.EnvironmentFile (
      builtins.length service.serviceConfig.EnvironmentFile - 1
    )
  ) services;
  identitySourceFiles = map (
    profile: cfg.age.secrets."buzz-hermes-${profile}-agent-env".file
  ) profiles;
  expectedPathEnvironment = {
    amosburton.CODEX_HOME = "/home/emiller/.codex";
    anne = {
      CODEX_HOME = "/home/emiller/.codex";
      WIKI_PATH = "/home/emiller/mill-docs/02_Areas/Relationship";
    };
    betty = {
      CODEX_HOME = "/var/lib/hermes-betty/.codex";
      WIKI_PATH = "/home/emiller/mill-docs/02_Areas/Home";
    };
    finn.CODEX_HOME = "/home/emiller/.codex";
    orchestrator = {
      CODEX_HOME = "/home/emiller/.codex";
      TN_VAULT_PATH = "/home/emiller/obsidian-vault";
      WIKI_PATH = "/home/emiller/obsidian-vault";
    };
    radar = { };
    scintillate = {
      CODEX_HOME = "/var/lib/hermes-scintillate/.codex";
      TN_VAULT_PATH = "/home/emiller/obsidian-vault";
      WIKI_PATH = "/home/emiller/obsidian-vault/03_Areas/Personal";
    };
  };
  channelId = channel: buzzBindings.channels.${channel}.id;
  expectedChannels = pkgs.lib.mapAttrs (
    _profile: profile: builtins.concatStringsSep "," (map channelId profile.channels)
  ) buzzBindings.profiles;
  expectedHomes = pkgs.lib.mapAttrs (_profile: profile: channelId profile.home) buzzBindings.profiles;
  moniEnabledProfiles = [
    "amosburton"
    "betty"
    "radar"
    "scintillate"
  ];

  profileAssertions =
    profile:
    let
      stateDir = "/var/lib/hermes-${profile}";
      profileConfig = cfg.services.hermes-agent.profiles.${profile};
      service = cfg.systemd.services."buzz-hermes-${profile}";
      expectedBindPaths = [ stateDir ] ++ builtins.attrNames profileConfig.hostPathMounts;
      containerOnlyEnvironmentValues = builtins.filter (
        value:
        builtins.isString value
        && (
          value == "/data"
          || pkgs.lib.hasPrefix "/data/" value
          || value == "/home/hermes"
          || pkgs.lib.hasPrefix "/home/hermes/" value
          || value == "/repos"
          || pkgs.lib.hasPrefix "/repos/" value
        )
      ) (builtins.attrValues service.environment);
    in
    [
      {
        test = service.environment.HERMES_PROFILE == profile;
        msg = "${profile}: Buzz runtime must select its canonical Hermes profile.";
      }
      {
        test = service.environment.HERMES_HOME == "${stateDir}/.hermes";
        msg = "${profile}: Buzz runtime must reuse the profile-owned Hermes home.";
      }
      {
        test = service.environment.BUZZ_RELAY_URL == "wss://millers.communities.buzz.xyz";
        msg = "${profile}: Buzz runtime must target the Millers community.";
      }
      {
        test =
          service.environment.BUZZ_ACP_AGENT_COMMAND == "${cfg.services.hermes-agent.package}/bin/hermes"
          && service.environment.BUZZ_ACP_AGENT_ARGS == "acp";
        msg = "${profile}: buzz-acp must launch the packaged Hermes ACP server.";
      }
      {
        test =
          service.environment.BUZZ_ACP_RESPOND_TO
          == (if builtins.elem profile moniEnabledProfiles then "allowlist" else "owner-only")
          &&
            service.environment.BUZZ_ACP_ALLOWED_RESPOND_TO
            == (if builtins.elem profile moniEnabledProfiles then "owner-only,allowlist" else "owner-only")
          && (
            if builtins.elem profile moniEnabledProfiles then
              service.environment.BUZZ_ACP_RESPOND_TO_ALLOWLIST == buzzBindings.moniPubkey
            else
              !(service.environment ? BUZZ_ACP_RESPOND_TO_ALLOWLIST)
          )
          && service.environment.BUZZ_ACP_SUBSCRIBE == "mentions"
          && service.environment.BUZZ_ACP_CHANNELS == expectedChannels.${profile}
          && service.environment.BUZZ_HOME_CHANNEL == expectedHomes.${profile}
          && service.environment.BUZZ_ACP_HEARTBEAT_INTERVAL == "0"
          && service.environment.BUZZ_ACP_LAZY_POOL == "true";
        msg = "${profile}: Buzz runtime must enforce its subscriptions, home, and signed mention policy.";
      }
      {
        test = service.serviceConfig.WorkingDirectory == "${stateDir}/workspace";
        msg = "${profile}: ACP sessions must start in the profile workspace.";
      }
      {
        test = service.serviceConfig.BindPaths == pkgs.lib.unique expectedBindPaths;
        msg = "${profile}: Buzz runtime must inherit exactly the declared profile host mounts.";
      }
      {
        test =
          service.serviceConfig.ProtectHome == "tmpfs"
          && service.serviceConfig.ProtectSystem == "strict"
          && service.serviceConfig.NoNewPrivileges
          &&
            service.serviceConfig.InaccessiblePaths == [
              "-/run/docker.sock"
              "-/run/podman/podman.sock"
            ]
          && service.serviceConfig.SystemCallArchitectures == "native";
        msg = "${profile}: Buzz runtime must retain the hardened filesystem boundary.";
      }
      {
        test =
          service.serviceConfig.EnvironmentFile
          == profileConfig.environmentFiles ++ [ cfg.age.secrets."buzz-hermes-${profile}-agent-env".path ];
        msg = "${profile}: runtime must load profile credentials plus one dedicated Buzz identity.";
      }
      {
        test =
          containerOnlyEnvironmentValues == [ ]
          && pkgs.lib.all (name: service.environment.${name} == expectedPathEnvironment.${profile}.${name}) (
            builtins.attrNames expectedPathEnvironment.${profile}
          );
        msg = "${profile}: host runtime must translate every container-only environment path.";
      }
    ];

  assertions = [
    {
      test =
        profiles == [
          "amosburton"
          "anne"
          "betty"
          "finn"
          "orchestrator"
          "radar"
          "scintillate"
        ];
      msg = "Buzz community runtime coverage must match the configured NUC Hermes profiles.";
    }
    {
      test =
        builtins.hasAttr "finn" cfg.services.hermes-agent.profiles
        &&
          cfg.services.hermes-agent.profiles.finn.hostPathMounts."/home/emiller/src/personal/finances"
          == "/repos/finances"
        && !(builtins.hasAttr "/home/emiller/src/personal/finances" cfg.services.hermes-agent.profiles.amosburton.hostPathMounts);
      msg = "Finn, not Amos Burton, must own the NUC finances checkout.";
    }
    {
      test = builtins.length (pkgs.lib.unique identityFiles) == builtins.length profiles;
      msg = "Every Buzz/Hermes runtime must use a distinct identity secret.";
    }
    {
      test = builtins.length (pkgs.lib.unique identitySourceFiles) == builtins.length profiles;
      msg = "Every Buzz/Hermes runtime must have a distinct encrypted identity source.";
    }
  ]
  ++ builtins.concatMap profileAssertions profiles;

  failures = builtins.filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "nuc-buzz-hermes-community-runtime" { } ''
  if [ ${toString (builtins.length failures)} -ne 0 ]; then
    cat >&2 <<'EOF'
  Buzz/Hermes community runtime assertions failed:
  ${builtins.concatStringsSep "\n" (map (failure: "- ${failure.msg}") failures)}
  EOF
    exit 1
  fi

  touch "$out"
''
