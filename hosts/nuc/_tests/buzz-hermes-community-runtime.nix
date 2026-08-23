# Pure Nix eval: each configured NUC Hermes profile must have an isolated
# Buzz community runtime that preserves its canonical host access boundary.
{
  nixosConfig,
  pkgs,
  bettyAgentSpec,
  buzzBindings,
}:
let
  cfg = nixosConfig.config;
  profiles = builtins.attrNames cfg.modules.services.hermes.agents;
  acpProfiles = builtins.filter (profile: profile != "scintillate") profiles;
  services = map (profile: cfg.systemd.services."buzz-hermes-${profile}") acpProfiles;
  identityFiles =
    map (
      service:
      builtins.elemAt service.serviceConfig.EnvironmentFile (
        builtins.length service.serviceConfig.EnvironmentFile - 1
      )
    ) services
    ++ [ cfg.age.secrets.buzz-hermes-scintillate-agent-env.path ];
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
    scintillate = {
      CODEX_HOME = "/var/lib/hermes-scintillate/.codex";
      TN_VAULT_PATH = "/home/emiller/obsidian-vault";
      WIKI_PATH = "/home/emiller/obsidian-vault/03_Areas/Personal";
    };
  };
  channelId = channel: buzzBindings.channels.${channel}.id;
  expectedHomes = pkgs.lib.mapAttrs (_profile: profile: channelId profile.home) buzzBindings.profiles;
  expectedSubscriptions = pkgs.lib.mapAttrs (
    _profile: profile:
    pkgs.lib.genAttrs profile.channels (channel: profile.channelSubscriptions.${channel} or "mentions")
  ) buzzBindings.profiles;
  moniEnabledProfiles = [
    "amosburton"
    "betty"
    "scintillate"
  ];
  scintillateProfile = cfg.services.hermes-agent.profiles.scintillate;
  scintillateGateway = cfg.systemd.services.hermes-gateway-scintillate;
  scintillateCron = cfg.systemd.services.hermes-scintillate-cron-tick;
  scintillatePresence = cfg.systemd.services.buzz-presence-scintillate;
  scintillateCronHeartbeatExpectedFailure = false;
  scintillateCronPostStartScripts = pkgs.lib.concatMapStringsSep "\n" (
    script: if builtins.pathExists script then builtins.readFile script else script
  ) (scintillateCron.serviceConfig.ExecStartPost or [ ]);
  scintillateCronHeartbeatConfigured = pkgs.lib.hasInfix "executor.json" scintillateCronPostStartScripts;
  scintillateBuzz = scintillateProfile.settings.gateway.platforms.buzz or { };
  scintillateBuzzDisplay = scintillateProfile.settings.display.platforms.buzz or { };
  scintillateBuzzPackages = builtins.filter (
    package: pkgs.lib.getName package == "buzz"
  ) scintillateProfile.extraPackages;
  scintillatePreStartScripts = pkgs.lib.concatMapStringsSep "\n" (
    script: if builtins.pathExists script then builtins.readFile script else script
  ) scintillateGateway.serviceConfig.ExecStartPre;

  profileAssertions =
    profile:
    let
      stateDir = "/var/lib/hermes-${profile}";
      profileConfig = cfg.services.hermes-agent.profiles.${profile};
      service = cfg.systemd.services."buzz-hermes-${profile}";
      subscriptionConfig = builtins.readFile service.environment.BUZZ_ACP_CONFIG;
      expectedRules = pkgs.lib.concatMapStringsSep "\n" (
        channel:
        let
          mode = expectedSubscriptions.${profile}.${channel};
          kinds =
            if buzzBindings.channels.${channel}.type == "forum" then
              "9, 46010, 40007, 45001, 45003"
            else
              "9, 46010, 40007";
        in
        ''
          [[rules]]
          name = "${profile}-${channel}"
          channels = ["${channelId channel}"]
          kinds = [${kinds}]
          require_mention = ${if mode == "mentions" then "true" else "false"}
        ''
      ) buzzProfile.channels;
      buzzProfile = buzzBindings.profiles.${profile};
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
          && service.environment.BUZZ_ACP_SUBSCRIBE == "config"
          && !(service.environment ? BUZZ_ACP_CHANNELS)
          && subscriptionConfig == expectedRules
          && service.environment.BUZZ_HOME_CHANNEL == expectedHomes.${profile}
          && service.environment.BUZZ_ACP_HEARTBEAT_INTERVAL == "0"
          && service.environment.BUZZ_ACP_LAZY_POOL == "true";
        msg = "${profile}: Buzz runtime must enforce its subscription mode, channels, home, and author policy.";
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
        bettyAgentSpec.materialization.skillPruneNames == [
          "lifetime-class-booking"
          "plan-moni-workouts"
        ];
      msg = "Betty materialization must prune retired fitness and Life Time skills from mutable runtime state.";
    }
    {
      test =
        profiles == [
          "amosburton"
          "anne"
          "betty"
          "finn"
          "orchestrator"
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
    {
      test = !(builtins.hasAttr "buzz-hermes-scintillate" cfg.systemd.services);
      msg = "Scintillate's legacy buzz-acp unit must be absent during the native gateway pilot.";
    }
    {
      test =
        scintillatePresence.enable
        && builtins.elem "hermes-gateway-scintillate.service" scintillatePresence.after
        && scintillatePresence.bindsTo == [ "hermes-gateway-scintillate.service" ]
        && scintillatePresence.partOf == [ "hermes-gateway-scintillate.service" ]
        && scintillatePresence.requires == [ "hermes-gateway-scintillate.service" ]
        && scintillatePresence.environment.BUZZ_ACP_RESPOND_TO == "nobody"
        && scintillatePresence.environment.BUZZ_ACP_AGENT_COMMAND == "${pkgs.coreutils}/bin/false"
        && scintillatePresence.environment.BUZZ_ACP_CHANNELS == expectedHomes.scintillate
        && scintillatePresence.environment.BUZZ_ACP_LAZY_POOL == "true"
        && scintillatePresence.environment.BUZZ_ACP_NO_BASE_PROMPT == "true"
        && scintillatePresence.environment.BUZZ_ACP_NO_MEMORY == "true"
        && scintillatePresence.environment.BUZZ_ACP_NO_TYPING == "true"
        &&
          scintillatePresence.serviceConfig.EnvironmentFile == [
            cfg.age.secrets.buzz-hermes-scintillate-agent-env.path
          ]
        &&
          scintillatePresence.serviceConfig.ExecStart
          == "${builtins.head scintillateBuzzPackages}/bin/buzz-acp";
      msg = "Scintillate's native Buzz gateway must have a lifecycle-bound, non-routing presence publisher.";
    }
    {
      test =
        scintillateGateway.enable
        && !scintillateGateway.restartIfChanged
        && scintillateProfile.stateDir == "/var/lib/hermes-scintillate"
        && scintillateProfile.package != cfg.services.hermes-agent.package
        && pkgs.lib.hasInfix "-buzz-pilot" (toString scintillateProfile.package)
        && scintillateProfile.package.pilotHermesVersion == "0.20.5"
        && scintillateCron.serviceConfig.ExecStart == "${scintillateProfile.package}/bin/hermes cron tick";
      msg = "Scintillate's gateway and cron executor must exclusively use the Hermes 0.20.5 Buzz pilot package without automatic mid-turn restarts.";
    }
    {
      test =
        if scintillateCronHeartbeatExpectedFailure then
          !scintillateCronHeartbeatConfigured
        else
          scintillateCronHeartbeatConfigured;
      msg = "Scintillate's host cron executor must publish a heartbeat that the gateway container can read.";
    }
    {
      test =
        scintillateBuzz.enabled
        && scintillateBuzz.extra.relay_url == "https://millers.communities.buzz.xyz"
        && scintillateBuzz.extra.cli_path == "${builtins.head scintillateBuzzPackages}/bin/buzz"
        && scintillateBuzz.extra.channels == map channelId buzzBindings.profiles.scintillate.channels
        && scintillateBuzz.extra.home_channel == expectedHomes.scintillate
        &&
          scintillateBuzz.extra.allowed_users == [
            buzzBindings.identities.edmund.pubkey
            buzzBindings.identities.moni.pubkey
          ]
        && scintillateBuzz.extra.require_mention
        && !scintillateBuzz.extra.allow_all_users
        && scintillateBuzz.extra.transport == "auto"
        && scintillateBuzz.extra.reply_in_thread
        && scintillateBuzz.extra.working_reaction == "⚙️";
      msg = "Scintillate's native Buzz adapter must preserve routing boundaries while enabling threaded replies and a transient working reaction.";
    }
    {
      test =
        !(scintillateBuzzDisplay.interim_assistant_messages or true)
        && !(scintillateBuzzDisplay.streaming or true)
        && !(scintillateProfile.settings.platforms ? telegram)
        && !(scintillateProfile.settings.platform_toolsets ? telegram)
        && !(scintillateProfile.environment ? PYTHONPATH)
        && builtins.length scintillateBuzzPackages == 1
        && builtins.elem cfg.age.secrets.buzz-hermes-scintillate-agent-env.path scintillateProfile.environmentFiles
        && pkgs.lib.hasInfix "grep '^BUZZ_'" scintillatePreStartScripts
        && pkgs.lib.hasInfix "grep -Ev '^(TELEGRAM_|BUZZ_)'" scintillatePreStartScripts
        && !pkgs.lib.hasInfix "grep '^TELEGRAM_'" scintillatePreStartScripts
        && pkgs.lib.hasInfix "reusing materialized Himalaya config" scintillatePreStartScripts
        && pkgs.lib.hasInfix ''platforms.pop("telegram", None)'' scintillatePreStartScripts;
      msg = "Scintillate's native Buzz gateway must load only its Buzz surface and purge stale Telegram runtime state.";
    }
  ]
  ++ builtins.concatMap profileAssertions acpProfiles;

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
