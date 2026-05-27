# Pure Nix eval test: assert structural properties of HA automation config.
#
# No VM needed — evaluates the NixOS module config and checks:
#   - Every automation has initial_state = true (use ensureEnabled from _lib.nix)
#   - Wake detection automations exist with guardrails
#   - Auto Good Morning automation is absent
#   - Required automations/scenes still exist
#   - Key scene state guarantees remain intact
{ nixosConfig, pkgs }:
let
  inherit (builtins)
    filter
    length
    any
    head
    concatStringsSep
    ;

  inherit (pkgs.lib) hasInfix;

  haConfig = nixosConfig.config.services.home-assistant.config;
  automations = haConfig.automation;
  scenes = haConfig.scene;

  findAutomation =
    id:
    let
      matches = filter (a: (a.id or null) == id) automations;
    in
    if matches == [ ] then null else head matches;

  findScene =
    name:
    let
      matches = filter (s: (s.name or null) == name) scenes;
    in
    if matches == [ ] then null else head matches;

  hasHomeAssistantStartTrigger =
    triggers: any (t: (t.platform or null) == "homeassistant" && (t.event or null) == "start") triggers;

  hasTimeTrigger =
    triggers: atTime: any (t: (t.platform or null) == "time" && (t.at or null) == atTime) triggers;

  hasActionCall =
    actions: actionName:
    any (a: (a.action or null) == actionName || (a.service or null) == actionName) actions;

  hasTimeGuard =
    conditions: target:
    any (c: (c.condition or null) == "time" && (c.after or null) == target) conditions;

  hasStateCondition =
    conditions: entityId: state:
    any (
      c:
      (c.condition or null) == "state" && (c.entity_id or null) == entityId && (c.state or null) == state
    ) conditions;

  toList =
    v:
    if builtins.isList v then
      v
    else if builtins.isAttrs v then
      [ v ]
    else
      [ ];

  allowedDisabledAutomations = [ "sync_iphone_alarm_8sleep" ];

  missingInitialState = filter (
    a: !(a.initial_state or null) && !(builtins.elem (a.id or "") allowedDisabledAutomations)
  ) automations;

  initialStateAssertions = map (a: {
    test = false;
    msg = "automation '${a.alias or a.id or "??"}' missing initial_state = true (use ensureEnabled from _lib.nix)";
  }) missingInitialState;

  # Must exist
  edmundAwake = findAutomation "edmund_awake_detection";
  monicaAwake = findAutomation "monica_awake_detection";
  circadianSleepHomeostasis = findAutomation "circadian_sleep_homeostasis";
  refreshEightSleepWakeSchedule = findAutomation "refresh_eight_sleep_wake_schedule";
  voiceWebhookSleep = findAutomation "voice_webhook_sleep";
  voiceWebhookInBed = findAutomation "voice_webhook_in_bed";
  bedtimeNudgeWebhook = findAutomation "bedtime_nudge_webhook";
  syncIphoneAlarm8sleep = findAutomation "sync_iphone_alarm_8sleep";
  sleepFocusOffEdmund = findAutomation "sleep_focus_off_stop_edmund";
  sleepFocusOffMonica = findAutomation "sleep_focus_off_stop_monica";
  alSleepModeOn = findAutomation "al_sleep_mode_on";
  alDaytimeSleepCorrection = findAutomation "al_daytime_sleep_correction";
  entranceOccupancyNightLight = findAutomation "entrance_occupancy_night_light";

  # Must stay removed
  goodMorningBothAwake = findAutomation "good_morning_both_awake";

  windingDownScene = findScene "Winding Down";
  getReadyForBedScene = findScene "Get Ready for Bed";
  goodNightScene = findScene "Good Night";
  inBedScene = findScene "In Bed";
  sleepScene = findScene "Sleep";
  goodMorningScene = findScene "Good Morning";
  midMorningScene = findScene "Mid-morning";
  sundownScene = findScene "Sundown";

  assertions = initialStateAssertions ++ [
    {
      test = edmundAwake != null;
      msg = "automation 'edmund_awake_detection' missing";
    }
    {
      test = monicaAwake != null;
      msg = "automation 'monica_awake_detection' missing";
    }
    {
      test = goodMorningBothAwake == null;
      msg = "automation 'good_morning_both_awake' should be removed";
    }

    {
      test = hasTimeGuard (toList (edmundAwake.condition or [ ])) "07:00:00";
      msg = "edmund_awake_detection missing time guard (after: 07:00:00)";
    }
    {
      test = hasTimeGuard (toList (monicaAwake.condition or [ ])) "07:00:00";
      msg = "monica_awake_detection missing time guard (after: 07:00:00)";
    }
    {
      test = hasStateCondition (toList (edmundAwake.condition or [ ])) "input_boolean.goodnight" "on";
      msg = "edmund_awake_detection missing condition: goodnight == on";
    }
    {
      test = hasStateCondition (toList (monicaAwake.condition or [ ])) "input_boolean.goodnight" "on";
      msg = "monica_awake_detection missing condition: goodnight == on";
    }

    {
      test = circadianSleepHomeostasis != null;
      msg = "automation 'circadian_sleep_homeostasis' missing";
    }
    {
      test = refreshEightSleepWakeSchedule != null;
      msg = "automation 'refresh_eight_sleep_wake_schedule' missing";
    }
    {
      test = hasInfix "latest_wake - 30 * 60" (circadianSleepHomeostasis.variables.ideal_wake_ts or "");
      msg = "circadian_sleep_homeostasis must compute ideal wake as latest wake minus 30-minute smart window";
    }
    {
      test = hasInfix "ideal_wake - 6 * 90 * 60" (circadianSleepHomeostasis.variables.sleep_ts or "");
      msg = "circadian_sleep_homeostasis must target six 90-minute cycles before ideal wake";
    }
    {
      test = voiceWebhookSleep == null;
      msg = "voice-facing Sleep webhook should be removed";
    }
    {
      test = voiceWebhookInBed == null;
      msg = "voice-facing In Bed webhook should be removed";
    }
    {
      test = bedtimeNudgeWebhook != null;
      msg = "automation 'bedtime_nudge_webhook' missing";
    }
    {
      test = syncIphoneAlarm8sleep != null && (syncIphoneAlarm8sleep.initial_state or null) == false;
      msg = "automation 'sync_iphone_alarm_8sleep' should remain present but declaratively disabled until an iOS alarm source exists";
    }
    {
      test = sleepFocusOffEdmund != null;
      msg = "automation 'sleep_focus_off_stop_edmund' missing";
    }
    {
      test = sleepFocusOffMonica != null;
      msg = "automation 'sleep_focus_off_stop_monica' missing";
    }
    {
      test = alSleepModeOn != null;
      msg = "automation 'al_sleep_mode_on' missing";
    }
    {
      test = alDaytimeSleepCorrection != null;
      msg = "automation 'al_daytime_sleep_correction' missing";
    }
    {
      test = entranceOccupancyNightLight != null;
      msg = "automation 'entrance_occupancy_night_light' missing";
    }

    {
      test = windingDownScene != null;
      msg = "scene 'Winding Down' missing";
    }
    {
      test = getReadyForBedScene != null;
      msg = "scene 'Get Ready for Bed' missing";
    }
    {
      test = goodNightScene != null;
      msg = "scene 'Good Night' missing";
    }
    {
      test = inBedScene == null;
      msg = "scene 'In Bed' should be removed";
    }
    {
      test = sleepScene != null;
      msg = "scene 'Sleep' missing";
    }
    {
      test = goodMorningScene != null;
      msg = "scene 'Good Morning' missing";
    }
    {
      test = midMorningScene != null;
      msg = "scene 'Mid-morning' missing";
    }
    {
      test = sundownScene != null;
      msg = "scene 'Sundown' missing";
    }

    {
      test =
        let
          trigger = circadianSleepHomeostasis.trigger or { };
        in
        (trigger.platform or null) == "time_pattern" && (trigger.minutes or null) == "/5";
      msg = "circadian_sleep_homeostasis must trigger every 5 minutes";
    }
    {
      test = hasTimeGuard (toList (circadianSleepHomeostasis.condition or [ ])) "20:00:00";
      msg = "circadian_sleep_homeostasis missing 8 PM time guard";
    }
    {
      test = hasStateCondition (toList (
        circadianSleepHomeostasis.condition or [ ]
      )) "person.edmund_miller" "home";
      msg = "circadian_sleep_homeostasis missing Edmund home guard";
    }
    {
      test = hasTimeTrigger (toList (alSleepModeOn.trigger or [ ])) "22:00:00";
      msg = "al_sleep_mode_on must trigger at 22:00:00";
    }
    {
      test = hasHomeAssistantStartTrigger (toList (alDaytimeSleepCorrection.trigger or [ ]));
      msg = "al_daytime_sleep_correction missing homeassistant start trigger";
    }
    {
      test = hasActionCall (toList (entranceOccupancyNightLight.action or [ ])) "adaptive_lighting.apply";
      msg = "entrance_occupancy_night_light missing adaptive_lighting.apply action";
    }

    {
      test =
        let
          coverCfg = goodMorningScene.entities."cover.smartwings_window_covering" or null;
        in
        builtins.isAttrs coverCfg
        && (coverCfg.state or null) == "open"
        && (coverCfg.current_position or null) == 20;
      msg = "Good Morning scene cover.smartwings_window_covering must use state=open + current_position=20";
    }

    {
      test = (windingDownScene.entities."input_boolean.edmund_awake" or null) == "off";
      msg = "Winding Down scene doesn't reset edmund_awake to off";
    }
    {
      test = (windingDownScene.entities."input_boolean.monica_awake" or null) == "off";
      msg = "Winding Down scene doesn't reset monica_awake to off";
    }
    {
      test = (goodMorningScene.entities."input_boolean.edmund_awake" or null) == "off";
      msg = "Good Morning scene doesn't reset edmund_awake to off";
    }
    {
      test = (goodMorningScene.entities."input_boolean.monica_awake" or null) == "off";
      msg = "Good Morning scene doesn't reset monica_awake to off";
    }
    {
      test = (goodMorningScene.entities."input_text.sleep_schedule_key" or null) == "";
      msg = "Good Morning scene doesn't reset sleep_schedule_key";
    }
    {
      test = (goodMorningScene.entities."input_boolean.goodnight" or null) == "off";
      msg = "Good Morning scene doesn't turn off goodnight";
    }
    {
      test = (goodMorningScene.entities."switch.eve_energy_20ebu4101" or null) == "off";
      msg = "Good Morning scene doesn't turn off whitenoise";
    }
    {
      test = (sleepScene.entities."switch.desk_monitor" or null) == "off";
      msg = "Sleep scene doesn't turn off switch.desk_monitor";
    }
    {
      test = (sleepScene.entities."switch.desk_pop" or null) == "off";
      msg = "Sleep scene doesn't turn off switch.desk_pop";
    }
    {
      test = (goodMorningScene.entities."switch.desk_monitor" or null) == "on";
      msg = "Good Morning scene doesn't turn on switch.desk_monitor";
    }
    {
      test = (goodMorningScene.entities."switch.desk_pop" or null) == "on";
      msg = "Good Morning scene doesn't turn on switch.desk_pop";
    }
    {
      test = (windingDownScene.entities."light.essentials_a19_a60_5" or null) == "on";
      msg = "Winding Down scene doesn't leave wall lamp on for low-light ambience";
    }
    {
      test = (sleepScene.entities."light.essentials_a19_a60_5" or null) == "off";
      msg = "Sleep scene doesn't turn off wall lamp";
    }
    {
      test = (goodMorningScene.entities."light.essentials_a19_a60_5" or null) == "on";
      msg = "Good Morning scene doesn't turn on wall lamp";
    }
    {
      test = (midMorningScene.entities."light.essentials_a19_a60_5" or null) == "off";
      msg = "Mid-morning scene doesn't turn off wall lamp";
    }
    {
      test =
        let
          cfg = sundownScene.entities."light.essentials_a19_a60_3" or null;
        in
        builtins.isAttrs cfg && (cfg.state or null) == "on" && (cfg.brightness or null) == 64;
      msg = "Sundown scene must set bathroom nightstand to 25% brightness";
    }
    {
      test =
        let
          cfg = sundownScene.entities."light.essentials_a19_a60_4" or null;
        in
        builtins.isAttrs cfg && (cfg.state or null) == "on" && (cfg.brightness or null) == 64;
      msg = "Sundown scene must set window nightstand to 25% brightness";
    }
  ];

  failures = filter (a: !a.test) assertions;
  failureMessages = map (a: "  FAIL: ${a.msg}") failures;

  resultText =
    if failures == [ ] then
      "All ${toString (length assertions)} HA automation assertions passed."
    else
      concatStringsSep "\n" (
        [
          "${toString (length failures)}/${toString (length assertions)} assertions failed:"
        ]
        ++ failureMessages
      );
in
pkgs.runCommand "ha-automation-assertions"
  {
    passthru = { inherit assertions failures; };
  }
  ''
    ${
      if failures == [ ] then
        ''
          echo "${resultText}"
          mkdir -p $out
          echo "${resultText}" > $out/result
        ''
      else
        ''
          echo "${resultText}" >&2
          exit 1
        ''
    }
  ''
