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
  adaptiveLighting = haConfig.adaptive_lighting or [ ];
  automations = haConfig.automation;
  scenes = haConfig.scene;
  scripts = haConfig.script;

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

  findAdaptiveLighting =
    name:
    let
      matches = filter (c: (c.name or null) == name) adaptiveLighting;
    in
    if matches == [ ] then null else head matches;

  hasHomeAssistantStartTrigger =
    triggers: any (t: (t.platform or null) == "homeassistant" && (t.event or null) == "start") triggers;

  hasStateTrigger =
    automation: entityId: state:
    any (
      t: (t.platform or null) == "state" && (t.entity_id or null) == entityId && (t.to or null) == state
    ) (toList (automation.trigger or [ ]));

  hasStateTriggerAny =
    automation: entityId:
    any (t: (t.platform or null) == "state" && (t.entity_id or null) == entityId) (
      toList (automation.trigger or [ ])
    );

  hasNumericStateCondition =
    conditions: entityId: above: below:
    any (
      c:
      (c.condition or null) == "numeric_state"
      && (c.entity_id or null) == entityId
      && (c.above or null) == above
      && (c.below or null) == below
    ) conditions;

  hasTemplateConditionContaining =
    conditions: text:
    any (c: (c.condition or null) == "template" && hasInfix text (c.value_template or "")) conditions;

  hasEventTrigger =
    automation: eventType:
    any (t: (t.platform or null) == "event" && (t.event_type or null) == eventType) (
      toList (automation.trigger or [ ])
    );

  hasActionCall =
    actions: actionName:
    any (a: (a.action or null) == actionName || (a.service or null) == actionName) actions;

  hasActionCallDeep =
    actions: actionName:
    any (
      a:
      (a.action or null) == actionName
      || (a.service or null) == actionName
      || (
        if a ? choose then
          any (c: hasActionCallDeep (toList (c.sequence or [ ])) actionName) a.choose
        else
          false
      )
      || (if a ? default then hasActionCallDeep (toList a.default) actionName else false)
      || (
        if a ? repeat && a.repeat ? sequence then
          hasActionCallDeep (toList a.repeat.sequence) actionName
        else
          false
      )
    ) actions;

  hasActionDataDeep =
    actions: actionName: key: value:
    any (
      a:
      ((a.action or null) == actionName || (a.service or null) == actionName)
      && (a.data.${key} or null) == value
      || (
        if a ? choose then
          any (c: hasActionDataDeep (toList (c.sequence or [ ])) actionName key value) a.choose
        else
          false
      )
      || (if a ? default then hasActionDataDeep (toList a.default) actionName key value else false)
      || (
        if a ? repeat && a.repeat ? sequence then
          hasActionDataDeep (toList a.repeat.sequence) actionName key value
        else
          false
      )
    ) actions;

  hasActionVariable =
    actions: variableName: any (a: a ? variables && builtins.hasAttr variableName a.variables) actions;

  hasTargetEntity = actions: entityId: any (a: (a.target.entity_id or null) == entityId) actions;

  hasTimeGuard =
    conditions: target:
    any (c: (c.condition or null) == "time" && (c.after or null) == target) conditions;

  hasTimeGuardDeep =
    conditions: target:
    any (
      c:
      ((c.condition or null) == "time" && (c.after or null) == target)
      || (if c ? conditions then hasTimeGuardDeep (toList c.conditions) target else false)
    ) conditions;

  hasTimePatternTrigger =
    automation: minutes:
    any (t: (t.platform or null) == "time_pattern" && (t.minutes or null) == minutes) (
      toList (automation.trigger or [ ])
    );

  hasStateCondition =
    conditions: entityId: state:
    any (
      c:
      (c.condition or null) == "state" && (c.entity_id or null) == entityId && (c.state or null) == state
    ) conditions;

  hasStateConditionDeep =
    conditions: entityId: state:
    any (
      c:
      (
        (c.condition or null) == "state" && (c.entity_id or null) == entityId && (c.state or null) == state
      )
      || (if c ? conditions then hasStateConditionDeep (toList c.conditions) entityId state else false)
    ) conditions;

  toList =
    v:
    if builtins.isList v then
      v
    else if builtins.isAttrs v then
      [ v ]
    else
      [ ];

  last = list: builtins.elemAt list ((length list) - 1);

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
  whiteNoiseWithBedtimeAudiobook = findAutomation "white_noise_with_bedtime_audiobook";
  syncIphoneAlarm8sleep = findAutomation "sync_iphone_alarm_8sleep";
  sleepFocusOffEdmund = findAutomation "sleep_focus_off_stop_edmund";
  sleepFocusOffMonica = findAutomation "sleep_focus_off_stop_monica";
  alDaytimeSleepCorrection = findAutomation "al_daytime_sleep_correction";
  entranceOccupancyNightLight = findAutomation "entrance_occupancy_night_light";
  arrivalFlashWallLamp = findAutomation "arrival_flash_wall_lamp";
  tvOnScript = scripts.tv_on or null;

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
  livingSpaceAdaptiveLighting = findAdaptiveLighting "Living Space";

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
      test = hasEventTrigger circadianSleepHomeostasis "sleep_homeostasis_test_tick";
      msg = "circadian_sleep_homeostasis missing hidden sleep_homeostasis_test_tick debug trigger";
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
      test = whiteNoiseWithBedtimeAudiobook != null;
      msg = "automation 'white_noise_with_bedtime_audiobook' missing";
    }
    {
      test = hasStateTrigger whiteNoiseWithBedtimeAudiobook "input_boolean.sleep_done" "on";
      msg = "white_noise_with_bedtime_audiobook must trigger when sleep_done turns on";
    }
    {
      test = hasStateTriggerAny whiteNoiseWithBedtimeAudiobook "sensor.edmund_s_eight_sleep_side_heart_rate";
      msg = "white_noise_with_bedtime_audiobook must re-check when Edmund Eight Sleep HR updates";
    }
    {
      test = hasStateTriggerAny whiteNoiseWithBedtimeAudiobook "sensor.monica_s_eight_sleep_side_heart_rate";
      msg = "white_noise_with_bedtime_audiobook must re-check when Monica Eight Sleep HR updates";
    }
    {
      test = !(hasStateTriggerAny whiteNoiseWithBedtimeAudiobook "media_player.bathroom");
      msg = "white_noise_with_bedtime_audiobook must not trigger from bathroom shower audio";
    }
    {
      test =
        let
          conditions = toList (whiteNoiseWithBedtimeAudiobook.condition or [ ]);
        in
        hasStateCondition conditions "input_boolean.goodnight" "on"
        && hasStateCondition conditions "input_boolean.sleep_done" "on"
        && hasNumericStateCondition conditions "sensor.edmund_s_eight_sleep_side_heart_rate" 35 130
        && hasNumericStateCondition conditions "sensor.monica_s_eight_sleep_side_heart_rate" 35 130
        && hasTemplateConditionContaining conditions "edmund_s_eight_sleep_side_heart_rate.last_updated"
        && hasTemplateConditionContaining conditions "monica_s_eight_sleep_side_heart_rate.last_updated"
        && !(hasStateConditionDeep conditions "binary_sensor.edmund_bed_presence_reliable" "on")
        && !(hasStateConditionDeep conditions "binary_sensor.monica_bed_presence_reliable" "on")
        && !(hasStateConditionDeep conditions "media_player.bathroom_nightstand" "playing")
        && !(hasStateConditionDeep conditions "media_player.window_nightstand" "playing");
      msg = "white_noise_with_bedtime_audiobook must require goodnight, sleep_done, and fresh HR without bed-presence or speaker gates";
    }
    {
      test =
        hasActionCall (toList (whiteNoiseWithBedtimeAudiobook.action or [ ])) "switch.turn_on"
        && hasTargetEntity (toList (
          whiteNoiseWithBedtimeAudiobook.action or [ ]
        )) "switch.eve_energy_20ebu4101";
      msg = "white_noise_with_bedtime_audiobook must turn on the whitenoise machine";
    }
    {
      test = syncIphoneAlarm8sleep != null && (syncIphoneAlarm8sleep.initial_state or null) == false;
      msg = "automation 'sync_iphone_alarm_8sleep' should remain present but declaratively disabled until an iOS alarm source exists";
    }
    {
      test =
        tvOnScript != null
        && hasActionCall (toList (tvOnScript.sequence or [ ])) "media_player.turn_on"
        && hasTargetEntity (toList (tvOnScript.sequence or [ ])) "media_player.living_room"
        && !(hasTargetEntity (toList (tvOnScript.sequence or [ ])) "media_player.tv");
      msg = "script.tv_on must target Living Room Apple TV, not Cast media_player.tv";
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
      test = alDaytimeSleepCorrection != null;
      msg = "automation 'al_daytime_sleep_correction' missing";
    }
    {
      test = entranceOccupancyNightLight != null;
      msg = "automation 'entrance_occupancy_night_light' missing";
    }
    {
      test = arrivalFlashWallLamp != null;
      msg = "automation 'arrival_flash_wall_lamp' missing";
    }
    {
      test = hasActionCall (toList (arrivalFlashWallLamp.action or [ ])) "scene.create";
      msg = "arrival_flash_wall_lamp must snapshot wall lamp state before flashing";
    }
    {
      test = hasActionVariable (toList (
        arrivalFlashWallLamp.action or [ ]
      )) "arrival_wall_lamp_previous_state";
      msg = "arrival_flash_wall_lamp must capture previous wall lamp state before flashing";
    }
    {
      test = hasActionCall (toList (arrivalFlashWallLamp.action or [ ])) "scene.turn_on";
      msg = "arrival_flash_wall_lamp must restore wall lamp state after flashing";
    }
    {
      test = hasActionCallDeep (toList (
        arrivalFlashWallLamp.action or [ ]
      )) "adaptive_lighting.set_manual_control";
      msg = "arrival_flash_wall_lamp must release Adaptive Lighting manual control after flashing";
    }
    {
      test = hasActionCallDeep (toList (arrivalFlashWallLamp.action or [ ])) "adaptive_lighting.apply";
      msg = "arrival_flash_wall_lamp must re-apply Adaptive Lighting after flashing";
    }
    {
      test = hasActionDataDeep (toList (
        arrivalFlashWallLamp.action or [ ]
      )) "adaptive_lighting.apply" "turn_on_lights" false;
      msg = "arrival_flash_wall_lamp must re-apply Adaptive Lighting without turning on an off lamp";
    }
    {
      test =
        (last (toList (arrivalFlashWallLamp.action or [ ]))).action or null == "adaptive_lighting.apply";
      msg = "arrival_flash_wall_lamp must finish by re-applying Adaptive Lighting";
    }
    {
      test = hasStateTrigger arrivalFlashWallLamp "person.edmund_miller" "Parking Lot";
      msg = "arrival_flash_wall_lamp must flash when Edmund enters Parking Lot";
    }
    {
      test = hasStateTrigger arrivalFlashWallLamp "person.moni" "Parking Lot";
      msg = "arrival_flash_wall_lamp must flash when Monica enters Parking Lot";
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
      test = hasTimePatternTrigger circadianSleepHomeostasis "/5";
      msg = "circadian_sleep_homeostasis must trigger every 5 minutes";
    }
    {
      test = hasTimeGuardDeep (toList (circadianSleepHomeostasis.condition or [ ])) "20:00:00";
      msg = "circadian_sleep_homeostasis missing 8 PM time guard";
    }
    {
      test = hasStateCondition (toList (
        circadianSleepHomeostasis.condition or [ ]
      )) "person.edmund_miller" "home";
      msg = "circadian_sleep_homeostasis missing Edmund home guard";
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
      test = (goodNightScene.entities."switch.eve_energy_20ebu4101" or null) == "off";
      msg = "Good Night scene must leave whitenoise off until audiobook speaker gate";
    }
    {
      test = (sleepScene.entities."switch.eve_energy_20ebu4101" or null) == "off";
      msg = "Sleep scene must leave whitenoise off until audiobook speaker gate";
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
      test =
        let
          cfg = windingDownScene.entities."light.essentials_a19_a60_5" or null;
        in
        builtins.isAttrs cfg
        && (cfg.state or null) == "on"
        && (cfg.brightness or null) == 115
        && (cfg.color_temp_kelvin or null) == 2700;
      msg = "Winding Down scene doesn't set wall lamp to reasonable low-light ambience";
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
        livingSpaceAdaptiveLighting != null
        && builtins.elem "light.essentials_a19_a60_5" (livingSpaceAdaptiveLighting.lights or [ ]);
      msg = "Living Space Adaptive Lighting must include wall lamp to avoid stale flash colors";
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

  failures = filter (
    a: (!a.test && !(a.expectedFailure or false)) || (a.test && (a.expectedFailure or false))
  ) assertions;
  failureMessages = map (
    a: if a.expectedFailure or false then "  XPASS: ${a.msg}" else "  FAIL: ${a.msg}"
  ) failures;

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
