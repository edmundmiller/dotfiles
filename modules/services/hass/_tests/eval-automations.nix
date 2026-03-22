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

  missingInitialState = filter (a: !(a.initial_state or null)) automations;

  initialStateAssertions = map (a: {
    test = false;
    msg = "automation '${a.alias or a.id or "??"}' missing initial_state = true (use ensureEnabled from _lib.nix)";
  }) missingInitialState;

  # Must exist
  edmundAwake = findAutomation "edmund_awake_detection";
  monicaAwake = findAutomation "monica_awake_detection";
  windingDown = findAutomation "winding_down";
  goodnightKeepNightstands = findAutomation "goodnight_keep_nightstands_off";
  bedPresenceInBed = findAutomation "bed_presence_in_bed";
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
      test = windingDown != null;
      msg = "automation 'winding_down' missing";
    }
    {
      test = goodnightKeepNightstands != null;
      msg = "automation 'goodnight_keep_nightstands_off' missing";
    }
    {
      test = bedPresenceInBed != null;
      msg = "automation 'bed_presence_in_bed' missing";
    }
    {
      test = bedtimeNudgeWebhook != null;
      msg = "automation 'bedtime_nudge_webhook' missing";
    }
    {
      test = syncIphoneAlarm8sleep != null;
      msg = "automation 'sync_iphone_alarm_8sleep' missing";
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
      test = hasTimeTrigger (toList (windingDown.trigger or [ ])) "22:00:00";
      msg = "winding_down must trigger at 22:00:00";
    }
    {
      test = hasTimeTrigger (toList (alSleepModeOn.trigger or [ ])) "22:00:00";
      msg = "al_sleep_mode_on must trigger at 22:00:00";
    }
    {
      test = hasStateTrigger (toList (
        bedPresenceInBed.trigger or [ ]
      )) "binary_sensor.monica_s_eight_sleep_side_bed_presence" "on";
      msg = "bed_presence_in_bed must trigger from Monica bed presence = on";
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
      test = (windingDownScene.entities."light.essentials_a19_a60_5" or null) == "off";
      msg = "Winding Down scene doesn't turn off wall lamp";
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
