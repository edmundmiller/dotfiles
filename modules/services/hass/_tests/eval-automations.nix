# Pure Nix eval test: assert structural properties of HA automation config.
#
# No VM needed — evaluates the NixOS module config and checks:
#   - Required automation IDs exist
#   - Wake detection has time guards (after 07:00)
#   - Good Morning has presence-aware awake template + time guard conditions
#   - Winding Down resets awake booleans
#
# Catches regressions like "someone removed the time guard" in seconds.
# Runs as: nix flake check (via checks.x86_64-linux.ha-automation-assertions)
#
# See also: validate-config.nix (HA's own schema validation at build time)
{ nixosConfig, pkgs }:
let
  inherit (builtins)
    filter
    length
    any
    head
    concatStringsSep
    ;

  # The fully-merged HA config from the NUC NixOS configuration
  haConfig = nixosConfig.config.services.home-assistant.config;
  automations = haConfig.automation;
  scenes = haConfig.scene;

  # ── Helpers ──────────────────────────────────────────────────────────────

  # Find automation by id
  findAutomation =
    id:
    let
      matches = filter (a: (a.id or null) == id) automations;
    in
    if matches == [ ] then null else head matches;

  # Find scene by name
  findScene =
    name:
    let
      matches = filter (s: (s.name or null) == name) scenes;
    in
    if matches == [ ] then null else head matches;

  # Check if a condition list contains a time condition with after >= target
  hasTimeGuard =
    conditions: target:
    any (c: (c.condition or null) == "time" && (c.after or null) == target) conditions;

  # Check if a condition list checks entity state
  hasStateCondition =
    conditions: entityId: state:
    any (
      c:
      (c.condition or null) == "state" && (c.entity_id or null) == entityId && (c.state or null) == state
    ) conditions;

  # Check if any template condition references a given entity ID
  hasTemplateRef =
    conditions: entityId:
    any (
      c:
      (c.condition or null) == "template"
      && builtins.isString (c.value_template or null)
      &&
        builtins.match (".*" + builtins.replaceStrings [ "." ] [ "\\." ] entityId + ".*") (
          c.value_template or ""
        ) != null
    ) conditions;

  # Normalize conditions to a list (HA accepts single or list)
  toConditionList =
    c:
    if builtins.isList c then
      c
    else if builtins.isAttrs c then
      [ c ]
    else
      [ ];

  # ── Automation lookups ───────────────────────────────────────────────────

  edmundAwake = findAutomation "edmund_awake_detection";
  monicaAwake = findAutomation "monica_awake_detection";
  goodMorningBothAwake = findAutomation "good_morning_both_awake";
  windingDown = findAutomation "winding_down";

  # ── Scene lookups ────────────────────────────────────────────────────────

  windingDownScene = findScene "Winding Down";
  goodMorningScene = findScene "Good Morning";

  # ── Assertions ───────────────────────────────────────────────────────────

  assertions = [
    # --- Required automations exist ---
    {
      test = edmundAwake != null;
      msg = "automation 'edmund_awake_detection' missing";
    }
    {
      test = monicaAwake != null;
      msg = "automation 'monica_awake_detection' missing";
    }
    {
      test = goodMorningBothAwake != null;
      msg = "automation 'good_morning_both_awake' missing";
    }
    {
      test = windingDown != null;
      msg = "automation 'winding_down' missing";
    }

    # --- Required scenes exist ---
    {
      test = windingDownScene != null;
      msg = "scene 'Winding Down' missing";
    }
    {
      test = goodMorningScene != null;
      msg = "scene 'Good Morning' missing";
    }

    # --- Time guards on wake detection (the 4:47 AM fix) ---
    {
      test = hasTimeGuard (toConditionList (edmundAwake.condition or [ ])) "07:00:00";
      msg = "edmund_awake_detection missing time guard (after: 07:00:00)";
    }
    {
      test = hasTimeGuard (toConditionList (monicaAwake.condition or [ ])) "07:00:00";
      msg = "monica_awake_detection missing time guard (after: 07:00:00)";
    }

    # --- Good Morning (both_awake) has time guard + both-awake conditions ---
    {
      test = hasTimeGuard (toConditionList (goodMorningBothAwake.condition or [ ])) "07:00:00";
      msg = "good_morning_both_awake missing time guard (after: 07:00:00)";
    }
    {
      test = hasTemplateRef (toConditionList (
        goodMorningBothAwake.condition or [ ]
      )) "input_boolean.edmund_awake";
      msg = "good_morning_both_awake missing condition referencing edmund_awake";
    }
    {
      test = hasTemplateRef (toConditionList (
        goodMorningBothAwake.condition or [ ]
      )) "input_boolean.monica_awake";
      msg = "good_morning_both_awake missing condition referencing monica_awake";
    }

    # --- Wake detection requires goodnight == on ---
    {
      test = hasStateCondition (toConditionList (
        edmundAwake.condition or [ ]
      )) "input_boolean.goodnight" "on";
      msg = "edmund_awake_detection missing condition: goodnight == on";
    }
    {
      test = hasStateCondition (toConditionList (
        monicaAwake.condition or [ ]
      )) "input_boolean.goodnight" "on";
      msg = "monica_awake_detection missing condition: goodnight == on";
    }

    # --- Winding Down scene resets awake booleans ---
    {
      test = (windingDownScene.entities."input_boolean.edmund_awake" or null) == "off";
      msg = "Winding Down scene doesn't reset edmund_awake to off";
    }
    {
      test = (windingDownScene.entities."input_boolean.monica_awake" or null) == "off";
      msg = "Winding Down scene doesn't reset monica_awake to off";
    }

    # --- Good Morning scene resets awake booleans (for next night) ---
    {
      test = (goodMorningScene.entities."input_boolean.edmund_awake" or null) == "off";
      msg = "Good Morning scene doesn't reset edmund_awake to off";
    }
    {
      test = (goodMorningScene.entities."input_boolean.monica_awake" or null) == "off";
      msg = "Good Morning scene doesn't reset monica_awake to off";
    }

    # --- Good Morning scene turns off goodnight ---
    {
      test = (goodMorningScene.entities."input_boolean.goodnight" or null) == "off";
      msg = "Good Morning scene doesn't turn off goodnight";
    }

    # --- Good Morning scene turns off whitenoise ---
    {
      test = (goodMorningScene.entities."switch.eve_energy_20ebu4101" or null) == "off";
      msg = "Good Morning scene doesn't turn off whitenoise";
    }
  ];

  # ── Evaluate ─────────────────────────────────────────────────────────────

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
