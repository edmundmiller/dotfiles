# Pure Nix eval: the NUC Hermes fleet must use one shared runtime package and
# expose each public Buzz identity through exactly one final-only native lane.
{
  nixosConfig,
  pkgs,
  agentRegistry,
  bettyAgentSpec,
  buzzBindings,
  discordBindings,
}:
let
  cfg = nixosConfig.config;
  inherit (pkgs) lib;
  profiles = builtins.attrNames cfg.services.hermes-agent.profiles;
  publicProfiles = builtins.attrNames buzzBindings.profiles;
  discordProfiles = builtins.attrNames (discordBindings.agents or { });
  expectedProfiles = [
    "amosburton"
    "anne"
    "betty"
    "finn"
    "orchestrator"
    "scintillate"
  ];
  expectedPublicProfiles = [
    "amosburton"
    "anne"
    "betty"
    "finn"
    "scintillate"
  ];
  fleetPackage = cfg.services.hermes-agent.package;
  channelId = channel: buzzBindings.channels.${channel}.id;
  gatewayName = profile: "hermes-gateway-${profile}";
  acpName = profile: "buzz-hermes-${profile}";
  presenceName = profile: "buzz-presence-${profile}";
  gatewayOf = profile: cfg.systemd.services.${gatewayName profile};
  hasAcp = profile: builtins.hasAttr (acpName profile) cfg.systemd.services;
  hasPresence = profile: builtins.hasAttr (presenceName profile) cfg.systemd.services;
  gatewayEnabled = profile: (gatewayOf profile).enable or false;
  nativeProfiles = builtins.filter gatewayEnabled publicProfiles;
  acpProfiles = builtins.filter hasAcp publicProfiles;
  identityFiles = map (
    profile: cfg.age.secrets."buzz-hermes-${profile}-agent-env".path
  ) publicProfiles;
  identitySourceFiles = map (
    profile: cfg.age.secrets."buzz-hermes-${profile}-agent-env".file
  ) publicProfiles;

  listValue = value: if builtins.isList value then value else [ value ];
  scriptRefs = values: lib.concatMapStringsSep "\n" toString values;
  containsPackage =
    package: packages: lib.any (candidate: toString candidate == toString package) packages;

  finalOnlyAssertions =
    profile:
    let
      settings = cfg.services.hermes-agent.profiles.${profile}.settings;
      inherit (settings) display;
      surfaceAssertions =
        surface:
        let
          surfaceDisplay = display.platforms.${surface};
        in
        [
          {
            test = surfaceDisplay.tool_progress == "off";
            msg = "${profile}: ${surface} must hide tool progress.";
          }
          {
            test = !surfaceDisplay.interim_assistant_messages && !surfaceDisplay.streaming;
            msg = "${profile}: ${surface} must emit only the durable final response.";
          }
          {
            test =
              !surfaceDisplay.show_reasoning
              && !surfaceDisplay.long_running_notifications
              && !surfaceDisplay.busy_ack_detail
              && !surfaceDisplay.busy_steer_ack_enabled;
            msg = "${profile}: ${surface} must hide reasoning, activity, and acknowledgement chatter.";
          }
        ];
    in
    [
      {
        test =
          display.tool_progress == "off"
          && !display.tool_progress_command
          && !display.interim_assistant_messages
          && !display.streaming
          && !display.show_reasoning
          && !display.long_running_notifications
          && !display.busy_ack_detail
          && !display.busy_steer_ack_enabled
          && display.busy_input_mode == "steer";
        msg = "${profile}: global display policy must be final-only with silent steering.";
      }
      {
        test =
          !settings.streaming.enabled
          && settings.streaming.transport == "off"
          && !settings.gateway.streaming.enabled
          && settings.gateway.streaming.transport == "off";
        msg = "${profile}: CLI and gateway streaming transports must remain disabled.";
      }
    ]
    ++ surfaceAssertions "buzz"
    ++ [
      {
        test = !(display.platforms ? discord) && !(settings.gateway.platforms ? discord);
        msg = "${profile}: Discord must be absent from the rendered Hermes profile.";
      }
    ];

  fleetPolicyAssertions =
    profile:
    let
      profileConfig = cfg.services.hermes-agent.profiles.${profile};
      inherit (profileConfig) settings;
      guardrails = settings.tool_loop_guardrails;
    in
    [
      {
        test = toString profileConfig.package == toString fleetPackage;
        msg = "${profile}: profile package must equal the shared Hermes fleet package.";
      }
      {
        test = settings.approvals.mode == "smart" && settings.approvals.cron_mode == "deny";
        msg = "${profile}: approvals must be smart interactively and denied in cron mode.";
      }
      {
        test =
          settings.agent.tool_use_enforcement == "auto"
          && settings.agent.stall_guards
          && settings.agent.bot_mode_protocol;
        msg = "${profile}: native tool enforcement, stall guards, and Bot Mode protocol must be enabled.";
      }
      {
        test =
          guardrails.warnings_enabled
          && guardrails.hard_stop_enabled
          && !(guardrails ? warn_after)
          && !(guardrails ? hard_stop_after)
          && !(guardrails ? loop_caps);
        msg = "${profile}: loop warnings and hard stop must use Hermes runtime thresholds, not stale profile caps.";
      }
      {
        test = profileConfig.configFile == null;
        msg = "${profile}: replacement config files must not bypass the canonical fleet policy.";
      }
    ];

  nativeAssertions =
    profile:
    let
      binding = buzzBindings.profiles.${profile};
      profileConfig = cfg.services.hermes-agent.profiles.${profile};
      identity = agentRegistry.${profile}.identity;
      gateway = gatewayOf profile;
      presence = cfg.systemd.services.${presenceName profile};
      buzz = profileConfig.settings.gateway.platforms.buzz;
      expectedAllowedUsers = [
        buzzBindings.identities.edmund.pubkey
      ]
      ++ lib.optional (binding.respondTo == "allowlist") buzzBindings.moniPubkey;
      expectedSubscriptions = builtins.listToAttrs (
        map (channel: {
          name = channelId channel;
          value = binding.channelSubscriptions.${channel} or "mentions";
        }) binding.channels
      );
      cleanupScripts = scriptRefs (listValue (gateway.serviceConfig.ExecStartPre or [ ]));
      identityFile = cfg.age.secrets."buzz-hermes-${profile}-agent-env".path;
    in
    [
      {
        test = gateway.enable && !hasAcp profile && hasPresence profile;
        msg = "${profile}: exactly the native gateway and presence companion must own its Buzz identity.";
      }
      {
        test =
          buzz.enabled
          && buzz.typing_indicator
          && buzz.extra.relay_url == "https://millers.communities.buzz.xyz"
          && lib.hasSuffix "/bin/buzz" buzz.extra.cli_path;
        msg = "${profile}: native Buzz must be enabled against the Millers relay with a packaged CLI.";
      }
      {
        test =
          buzz.extra.channels == map channelId binding.channels
          && buzz.extra.home_channel == channelId binding.home
          && buzz.extra.allowed_users == expectedAllowedUsers
          && buzz.extra.require_mention
          && !buzz.extra.allow_all_users
          && buzz.extra.transport == "auto"
          && buzz.extra.reply_in_thread
          && buzz.extra.working_reaction == "⚙️"
          && buzz.extra.channel_subscriptions == expectedSubscriptions;
        msg = "${profile}: native Buzz routing, authors, same-thread replies, and transient gear signal must match the deployment binding.";
      }
      {
        test =
          buzz.extra.profile_name == identity.displayName
          && buzz.extra.profile_avatar_url == identity.avatarUrl
          && buzz.extra.profile_about == identity.bio;
        msg = "${profile}: native Buzz must render the canonical name, avatar, and bio.";
      }
      {
        test =
          builtins.elem identityFile profileConfig.environmentFiles
          && gateway.serviceConfig.EnvironmentFile == profileConfig.environmentFiles;
        msg = "${profile}: native gateway must load its dedicated encrypted Buzz identity through the profile boundary.";
      }
      {
        test =
          presence.enable
          && builtins.elem "${gatewayName profile}.service" presence.after
          && presence.requires == [ "${gatewayName profile}.service" ]
          && presence.bindsTo == [ "${gatewayName profile}.service" ]
          && presence.partOf == [ "${gatewayName profile}.service" ]
          && presence.environment.BUZZ_ACP_RESPOND_TO == "nobody"
          && presence.environment.BUZZ_ACP_AGENT_COMMAND == "${pkgs.coreutils}/bin/false"
          &&
            presence.environment.BUZZ_ACP_CHANNELS == lib.concatStringsSep "," (map channelId binding.channels)
          && presence.environment.BUZZ_ACP_NO_BASE_PROMPT == "true"
          && presence.environment.BUZZ_ACP_NO_MEMORY == "true"
          && presence.environment.BUZZ_ACP_NO_TYPING == "true"
          && presence.serviceConfig.EnvironmentFile == [ identityFile ];
        msg = "${profile}: presence companion must be lifecycle-bound, silent, and unable to launch an agent.";
      }
      {
        test = lib.hasInfix "hermes-${profile}-native-state-cleanup" cleanupScripts;
        msg = "${profile}: native gateway must purge stale Telegram runtime state before startup.";
      }
    ];

  scintillateCron = cfg.systemd.services.hermes-scintillate-cron-tick;
  scintillateCronPostStart = scriptRefs (scintillateCron.serviceConfig.ExecStartPost or [ ]);
  scintillateGateway = gatewayOf "scintillate";
  scintillatePreStart = scriptRefs (listValue (scintillateGateway.serviceConfig.ExecStartPre or [ ]));
  orchestratorGateway = gatewayOf "orchestrator";
  orchestratorPreStart = scriptRefs (
    listValue (orchestratorGateway.serviceConfig.ExecStartPre or [ ])
  );
  orchestratorSettings = cfg.services.hermes-agent.profiles.orchestrator.settings;

  assertions = [
    {
      test = profiles == expectedProfiles && publicProfiles == expectedPublicProfiles;
      msg = "Fleet coverage must remain six profiles with exactly five public Buzz identities.";
    }
    {
      test = discordProfiles == [ ];
      msg = "The NUC must not expose any public Hermes identity through Discord.";
    }
    {
      test = nativeProfiles == expectedPublicProfiles && acpProfiles == [ ];
      msg = "Checked-in final state must migrate all five public identities to native Buzz and remove every ACP response lane.";
    }
    {
      test =
        lib.all (profile: (gatewayEnabled profile) != (hasAcp profile)) publicProfiles
        && lib.all (profile: hasPresence profile == gatewayEnabled profile) publicProfiles;
      msg = "Every public identity must have exactly one response transport and presence only with native Buzz.";
    }
    {
      test =
        fleetPackage.hermesVersion == "0.20.5"
        && fleetPackage.hermesRelease == "v2026.8.19"
        && fleetPackage.smartModelRouting
        && !(fleetPackage ? pilotHermesVersion)
        && !lib.hasInfix "buzz-pilot" (toString fleetPackage);
      msg = "Fleet must converge on the shared patched Hermes v0.20.5 package, not a pilot split.";
    }
    {
      test = cfg.services.hermes-agent.configFile == null;
      msg = "Top-level replacement config file must not bypass the canonical fleet policy.";
    }
    {
      test = builtins.length (lib.unique identityFiles) == builtins.length publicProfiles;
      msg = "Every public profile must use a distinct decrypted Buzz identity file.";
    }
    {
      test = builtins.length (lib.unique identitySourceFiles) == builtins.length publicProfiles;
      msg = "Every public profile must use a distinct encrypted Buzz identity source.";
    }
    {
      test =
        !(builtins.hasAttr (acpName "orchestrator") cfg.systemd.services)
        && !(builtins.hasAttr (presenceName "orchestrator") cfg.systemd.services)
        && !(builtins.hasAttr "buzz-hermes-orchestrator-agent-env" cfg.age.secrets)
        && !(((orchestratorSettings.gateway or { }).platforms or { }) ? buzz);
      msg = "Orchestrator must remain internal with no Buzz transport, presence, or identity secret.";
    }
    {
      test =
        lib.all (
          profile:
          cfg.services.hermes-agent.profiles.${profile}.environment.HERMES_KANBAN_DISPATCH_IN_GATEWAY
          == "false"
        ) publicProfiles
        &&
          cfg.services.hermes-agent.profiles.orchestrator.environment.HERMES_KANBAN_DISPATCH_IN_GATEWAY
          == "true"
        && lib.hasInfix "hermes-orchestrator-profile-list-mirror" orchestratorPreStart;
      msg = "Only Orchestrator may dispatch the shared Kanban board, with the canonical profile roster available before startup.";
    }
    {
      test =
        !((orchestratorSettings.display or { }) ? interim_assistant_messages)
        && !((orchestratorSettings.display or { }) ? streaming)
        && !((orchestratorSettings.display or { }) ? long_running_notifications)
        && !(orchestratorSettings ? streaming)
        && !((orchestratorSettings.gateway or { }) ? streaming);
      msg = "Visible-bot final-only display policy must not be forced onto hidden Orchestrator.";
    }
    {
      test =
        cfg.systemd.services.hermes-amosburton-cron-tick.serviceConfig.ExecStart
        == "${fleetPackage}/bin/hermes cron tick"
        && scintillateCron.serviceConfig.ExecStart == "${fleetPackage}/bin/hermes cron tick"
        && containsPackage fleetPackage cfg.systemd.services.hermes-betty-cron-tick.path
        && containsPackage fleetPackage cfg.systemd.services.hermes-betty-good-morning-dj.path
        && containsPackage fleetPackage cfg.systemd.services.hermes-scintillate-desktop-dashboard.path;
      msg = "Gateways, cron executors, one-shot automation, and dashboard must share one Hermes package lane.";
    }
    {
      test =
        scintillateGateway.enable
        && !scintillateGateway.restartIfChanged
        && lib.hasInfix "hermes-scintillate-native-state-cleanup" scintillatePreStart
        && lib.hasInfix "hermes-scintillate-container-refresh" scintillatePreStart
        && lib.hasInfix "hermes-scintillate-himalaya-fastmail-setup" scintillatePreStart
        && lib.hasInfix "hermes-scintillate-gateway-dotenv" scintillatePreStart;
      msg = "Scintillate must preserve its bounded restart and retired Telegram cleanup behavior on the shared package.";
    }
    {
      test = lib.hasInfix "hermes-scintillate-cron-executor-heartbeat" scintillateCronPostStart;
      msg = "Scintillate cron executor must continue publishing its gateway-readable heartbeat.";
    }
    {
      test =
        builtins.hasAttr "canonical-hermes-profiles-materialize" cfg.system.activationScripts
        && builtins.hasAttr "hermesSharedProfilesAggregate" cfg.system.activationScripts;
      msg = "Canonical metadata merge and shared profile aggregation activation phases must remain installed.";
    }
    {
      test =
        bettyAgentSpec.materialization.skillPruneNames == [
          "lifetime-class-booking"
          "plan-moni-workouts"
        ];
      msg = "Betty materialization must keep retired fitness and Life Time skills pruned.";
    }
    {
      test =
        cfg.services.hermes-agent.profiles.finn.hostPathMounts."/home/emiller/src/personal/finances"
        == "/repos/finances"
        && !(builtins.hasAttr "/home/emiller/src/personal/finances" cfg.services.hermes-agent.profiles.amosburton.hostPathMounts);
      msg = "Finn, not Amos Burton, must own the NUC finances checkout.";
    }
    {
      test =
        buzzBindings.profiles.betty.channelSubscriptions.meal-planning == "all"
        && (buzzBindings.profiles.betty.channelSubscriptions.mill-docs or "mentions") == "mentions";
      msg = "Betty must remain ambient in meal-planning and mention-gated in mill-docs.";
    }
  ]
  ++ builtins.concatMap fleetPolicyAssertions profiles
  ++ builtins.concatMap finalOnlyAssertions publicProfiles
  ++ builtins.concatMap nativeAssertions nativeProfiles;

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
