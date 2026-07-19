# Regression contract for the 2026-07 Betty scheduler outage.
{
  nixosConfig,
  pkgs,
  bettyAgentSpec,
}:
let
  cfg = nixosConfig.config;
  bettyService = cfg.systemd.services.hermes-betty-cron-tick;
  bettyTimer = cfg.systemd.timers.hermes-betty-cron-tick;
  bettyGateway = cfg.systemd.services.hermes-gateway-betty;
  bettySecretMaterialization = cfg.system.activationScripts.hermesBettySecretsMaterialize.text;
  bettyGoodMorningDj = cfg.systemd.services.hermes-betty-good-morning-dj;
  bettyGoodMorningDjExecStart = toString bettyGoodMorningDj.serviceConfig.ExecStart;
  # Canonical agent-owned helper/prompt (not Linux store paths — cross-eval safe).
  bettyGoodMorningDjHelper = builtins.readFile bettyAgentSpec.automations.goodMorningDj.helper;
  bettyGoodMorningDjPrompt = builtins.readFile bettyAgentSpec.automations.goodMorningDj.prompt;
  bettyGoodMorningDjAll =
    bettyGoodMorningDjHelper + "\n" + bettyGoodMorningDjPrompt + "\n" + bettyGoodMorningDjExecStart;
  goodMorningScript = cfg.services.home-assistant.config.script.good_morning;
  goodMorningShellCommand =
    cfg.services.home-assistant.config.shell_command.hermes_betty_good_morning_dj;

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
      test = hasInfix "HERMES_HOME=/var/lib/hermes-betty/.hermes" (
        concatStringsSep " " bettyService.serviceConfig.Environment
      );
      msg = "Betty cron executor must target Betty's isolated Hermes home.";
    }
    {
      test = hasInfix "/var/lib/hermes-betty" (
        concatStringsSep " " bettyService.serviceConfig.ReadWritePaths
      );
      msg = "Betty cron executor must be able to update Betty's cron state.";
    }
    {
      test = hasInfix "DISCORD_HOME_CHANNEL=1494160879803957379" (
        concatStringsSep " " bettyService.serviceConfig.Environment
      );
      msg = "Betty cron executor must resolve bare Discord delivery through Betty's deployment binding.";
    }
    {
      test = hasInfix "/etc/opnix-token" bettySecretMaterialization;
      msg = "Betty secrets must be materialized by root with the NUC 1Password service token.";
    }
    {
      test = builtins.all (envVar: hasInfix envVar bettySecretMaterialization) [
        "DISCORD_BOT_TOKEN"
        "LIFETIME_USERNAME"
        "LIFETIME_PASSWORD"
        "HERMES_MCP_BEARER_TOKEN_LINEAR"
      ];
      msg = "Betty's generated service environment must contain Discord, Life Time, and Linear secrets.";
    }
    {
      test = builtins.elem "onepassword-secrets" bettyService.serviceConfig.SupplementaryGroups;
      msg = "Betty cron executor must be able to read the root-owned 1Password service token.";
    }
    {
      test = hasInfix "hermes-betty-cron-executor" (toString bettyService.serviceConfig.ExecStart);
      msg = "Betty cron executor must export the 1Password service token before launching Hermes.";
    }
    {
      test = bettyGoodMorningDj.serviceConfig.Type == "oneshot";
      msg = "Betty Good Morning DJ must be a one-shot service.";
    }
    {
      test = bettyGoodMorningDj.serviceConfig.User == "emiller";
      msg = "Betty Good Morning DJ must run as Betty's profile owner.";
    }
    {
      test = hasInfix "HERMES_HOME=/var/lib/hermes-betty/.hermes" (
        concatStringsSep " " bettyGoodMorningDj.serviceConfig.Environment
      );
      msg = "Betty Good Morning DJ must target Betty's isolated Hermes home.";
    }
    {
      test = builtins.elem "/run/hermes-betty-env/secrets.env" bettyGoodMorningDj.serviceConfig.EnvironmentFile;
      msg = "Betty Good Morning DJ must use Betty's materialized environment.";
    }
    {
      test = hasInfix "HASS_URL=http://127.0.0.1:8123" (
        concatStringsSep " " bettyGoodMorningDj.serviceConfig.Environment
      );
      msg = "Betty Good Morning DJ must target local Home Assistant via HASS_URL.";
    }
    {
      test =
        hasInfix "added_uris" bettyGoodMorningDjAll
        && hasInfix "player_queues/items" bettyGoodMorningDjHelper
        && hasInfix "MUSIC_ASSISTANT_TOKEN" bettyGoodMorningDjHelper
        && hasInfix "media_player.kitchen" bettyGoodMorningDjHelper
        && hasInfix "Good Morning" bettyGoodMorningDjAll
        && hasInfix "receipt" bettyGoodMorningDjAll
        && hasInfix "websockets" bettyGoodMorningDjHelper
        && hasInfix "exactly 5 distinct track uris" bettyGoodMorningDjHelper
        && hasInfix "playlist_lookup_parts" bettyGoodMorningDjHelper
        && hasInfix "music/playlists/get_playlist" bettyGoodMorningDjHelper
        && hasInfix "playlist_tracks" bettyGoodMorningDjHelper
        && hasInfix "playlist_uri" bettyGoodMorningDjAll
        && hasInfix "assert_queue_matches_playlist" bettyGoodMorningDjHelper
        && hasInfix "current_track" bettyGoodMorningDjHelper
        && hasInfix "betty-hermes-good-morning-dj" bettyGoodMorningDjExecStart
        && !hasInfix "SuccessExitStatus" bettyGoodMorningDjExecStart;
      msg = "Betty Good Morning DJ must verify exact Good Morning playlist identity plus receipt track URIs.";
    }
    {
      test = hasInfix "MUSIC_ASSISTANT_TOKEN" bettySecretMaterialization;
      msg = "Betty secrets materialization must export the Music Assistant WS token for DJ verification.";
    }
    {
      test = hasInfix "MUSIC_ASSISTANT_URL=http://127.0.0.1:8095" (
        concatStringsSep " " bettyGoodMorningDj.serviceConfig.Environment
      );
      msg = "Betty Good Morning DJ must target local Music Assistant over loopback.";
    }
    {
      test =
        builtins.any (p: hasInfix "-curl-" (toString p)) bettyGoodMorningDj.path
        && builtins.any (p: hasInfix "-jq-" (toString p)) bettyGoodMorningDj.path;
      msg = "Betty Good Morning DJ PATH must include curl and jq for skill smoke helpers.";
    }
    {
      test = hasInfix "betty-hermes" (toString bettyGoodMorningDj.serviceConfig.ExecStart);
      msg = "Betty Good Morning DJ must run through Betty's canonical launcher.";
    }
    {
      test = hasInfix "hermes-betty-good-morning-dj.service" goodMorningShellCommand;
      msg = "Home Assistant must start Betty's Good Morning DJ unit.";
    }
    {
      test = builtins.any (
        action: (action.action or "") == "shell_command.hermes_betty_good_morning_dj"
      ) goodMorningScript.sequence;
      msg = "The Good Morning script must invoke Betty's DJ command.";
    }
    {
      test = hasInfix "HERMES_SPOTIFY_CLIENT_ID" bettySecretMaterialization;
      msg = "Betty's environment must materialize the Spotify client ID.";
    }
    {
      test =
        hasInfix "/bin/flock /var/lib/hermes-betty/.profile.lock" (
          toString bettyService.serviceConfig.ExecStart
        )
        && hasInfix "/bin/flock /var/lib/hermes-betty/.profile.lock" (
          toString bettyGoodMorningDj.serviceConfig.ExecStart
        );
      msg = "Betty cron and Good Morning DJ executors must share an exclusive profile lock.";
    }
    {
      test = builtins.elem "music_assistant" cfg.services.home-assistant.extraComponents;
      msg = "Home Assistant must package the Music Assistant integration.";
    }
    {
      test = builtins.elem "eno1" cfg.networking.firewall.trustedInterfaces;
      msg = "Music Assistant must accept dynamic player traffic from the NUC LAN.";
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
