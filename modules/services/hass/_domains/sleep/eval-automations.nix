# Pure Nix eval test: assert structural properties of HA sleep config.
#
# No VM needed — evaluates merged NixOS config and checks:
#   - Every automation has initial_state = true
#   - Wake detection automations exist and keep morning guards
#   - Auto Good Morning automation stays removed
#   - Core sleep + cross-domain safety automations exist
{ nixosConfig, pkgs }:
let
  inherit (builtins)
    filter
    length
    any
    head
    concatStringsSep
    ;

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

  hasStateTrigger =
    triggers: entityId: toState:
    any (
      t: (t.platform or null) == "state" && (t.entity_id or null) == entityId && (t.to or null) == toState
    ) triggers;

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
  bedPresenceInBed = findAutomation "bed_presence_in_bed";
  syncIphoneAlarm8sleep = findAutomation "sync_iphone_alarm_8sleep";
  sleepFocusOffEdmund = findAutomation "sleep_focus_off_stop_edmund";
  sleepFocusOffMonica = findAutomation "sleep_focus_off_stop_monica";
  bedtimeNudgeWebhook = findAutomation "bedtime_nudge_webhook";
  alDaytimeSleepCorrection = findAutomation "al_daytime_sleep_correction";
  entranceOccupancyNightLight = findAutomation "entrance_occupancy_night_light";

  # Must stay removed
  goodMorningBothAwake = findAutomation "good_morning_both_awake";

  windingDownScene = findScene "Winding Down";
  getReadyForBedScene = findScene "Get Ready for Bed";
  goodNightScene = findScene "Good Night";
  sleepScene = findScene "Sleep";
  goodMorningScene = findScene "Good Morning";

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
      msg = "automation 'good_morning_both_awake' should remain removed";
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
      test = bedPresenceInBed != null;
      msg = "automation 'bed_presence_in_bed' missing";
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
      test =
        sleepFocusOffEdmund != null
        && !(hasActionCall (toList (sleepFocusOffEdmund.action or [ ])) "eight_sleep.alarm_dismiss");
      msg = "sleep_focus_off_stop_edmund must not call unavailable eight_sleep.alarm_dismiss";
    }
    {
      test =
        sleepFocusOffMonica != null
        && !(hasActionCall (toList (sleepFocusOffMonica.action or [ ])) "eight_sleep.alarm_dismiss");
      msg = "sleep_focus_off_stop_monica must not call unavailable eight_sleep.alarm_dismiss";
    }
    {
      test = bedtimeNudgeWebhook != null;
      msg = "automation 'bedtime_nudge_webhook' missing";
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
      test = hasStateTrigger (toList (
        bedPresenceInBed.trigger or [ ]
      )) "binary_sensor.monica_s_eight_sleep_side_bed_presence" "on";
      msg = "bed_presence_in_bed must trigger from Monica bed presence = on";
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
      test = sleepScene != null;
      msg = "scene 'Sleep' missing";
    }
    {
      test = goodMorningScene != null;
      msg = "scene 'Good Morning' missing";
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
      test = hasHomeAssistantStartTrigger (toList (alDaytimeSleepCorrection.trigger or [ ]));
      msg = "al_daytime_sleep_correction missing homeassistant start trigger";
    }

    {
      test = hasActionCall (toList (entranceOccupancyNightLight.action or [ ])) "adaptive_lighting.apply";
      msg = "entrance_occupancy_night_light missing adaptive_lighting.apply action";
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
      test =
        (windingDownScene.entities."switch.adaptive_lighting_sleep_mode_living_space" or null) == "off";
      msg = "Winding Down scene must keep AL sleep mode off";
    }
    {
      test =
        (getReadyForBedScene.entities."switch.adaptive_lighting_sleep_mode_living_space" or null) == "off";
      msg = "Get Ready for Bed scene must keep AL sleep mode off";
    }
    {
      test = (goodNightScene.entities."switch.adaptive_lighting_sleep_mode_living_space" or null) == "on";
      msg = "Good Night scene must enable AL sleep mode";
    }
    {
      test = (sleepScene.entities."switch.adaptive_lighting_sleep_mode_living_space" or null) == "on";
      msg = "Sleep scene must enable AL sleep mode";
    }
    {
      test = (goodMorningScene.entities."input_boolean.goodnight" or null) == "off";
      msg = "Good Morning scene doesn't turn off goodnight";
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
