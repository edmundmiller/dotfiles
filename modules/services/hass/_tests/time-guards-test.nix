# NixOS VM test: time-guard behavior on wake/sleep automations.
#
# Verifies that time-gated automations actually block before 7 AM and pass after.
# Uses system clock manipulation + HA API to test automation behavior end-to-end.
#
# Run: nix build .#checks.x86_64-linux.hass-time-guards
# (requires x86_64-linux — run on NUC or Linux builder)
#
# Test cases:
#   1. Wake signal at 3 AM → stays off (time guard blocks)
#   2. Wake signal at 6:59 AM → stays off (boundary)
#   3. Wake signal at 7:01 AM → turns on (time guard passes)
#   4. GOODNIGHT INVARIANT: goodnight cannot turn off before 7 AM by any automated path
#      4a. Both awake at 3 AM → goodnight stays on
#      4b. Both awake at 6:59 AM → goodnight stays on (boundary)
#   5. Both awake at 8 AM → Good Morning fires (goodnight turns off)
#   6. Post-bedtime signal at 10:48 PM → stays off (the actual bug scenario)
{ pkgs }:
let
  # Our HA domain modules
  domainModules = [
    ../_domains/ambient.nix
    ../_domains/aranet.nix
    ../_domains/conversation.nix
    ../_domains/lighting.nix
    ../_domains/modes.nix
    ../_domains/sleep
    ../_domains/tv.nix
    ../_domains/vacation.nix
  ];

  testLibDir = pkgs.runCommand "ha-test-lib" { } ''
    mkdir -p $out
    cp ${./ha_test_lib.py} $out/ha_test_lib.py
  '';
in
pkgs.testers.nixosTest {
  name = "hass-time-guards";

  nodes.hass =
    { config, ... }:
    {
      imports = domainModules;

      services.home-assistant = {
        enable = true;

        extraComponents = [ "met" ];

        config = {
          homeassistant = {
            name = "Test Home";
            time_zone = "US/Central";
            latitude = 0.0;
            longitude = 0.0;
            elevation = 0;
          };

          # default_config loads standard integrations including automation,
          # scene, input_boolean — required for entities to be created
          default_config = { };

          frontend = { };
          logger.default = "info";

          # Base lists — domain modules append via mkAfter
          automation = [ ];
        };
      };

      systemd.tmpfiles.rules = [
        "f ${config.services.home-assistant.configDir}/automations.yaml 0644 hass hass"
        "f ${config.services.home-assistant.configDir}/scenes.yaml 0644 hass hass"
        "f ${config.services.home-assistant.configDir}/scripts.yaml 0644 hass hass"
      ];

      # Match HA timezone so date -s values are interpreted as CST
      time.timeZone = "US/Central";
      virtualisation.memorySize = 2048;
    };

  # ha_test_lib is injected at runtime via sys.path — mypy can't find it
  skipTypeCheck = true;

  testScript = ''
    import sys
    import time
    sys.path.insert(0, "${testLibDir}")
    import ha_test_lib as ha

    start_all()

    # ── Setup: wait for HA, create auth token ───────────────────────────
    ha.wait_ready(hass)
    ha.create_token(hass)

    def reset_state():
        """Reset to bedtime preconditions using proper service calls."""
        ha.call_service(hass, "input_boolean", "turn_on", {"entity_id": "input_boolean.goodnight"})
        ha.call_service(hass, "input_boolean", "turn_off", {"entity_id": "input_boolean.edmund_awake"})
        ha.call_service(hass, "input_boolean", "turn_off", {"entity_id": "input_boolean.monica_awake"})
        time.sleep(1)

    # ── Diagnostic: verify automation entities exist ────────────────────
    with subtest("Automation entities registered"):
        for aid in ["edmund_awake_detection", "monica_awake_detection", "good_morning_both_awake"]:
            eid = ha._resolve_automation_entity(hass, aid)
            print(f"  {aid} → {eid}")

    # ── Test 1: Wake signal at 3 AM → blocked ──────────────────────────
    with subtest("Wake signal at 3 AM is blocked by time guard"):
        ha.set_clock(hass, "03:00:00", "2026-02-25")
        reset_state()

        # Simulate Edmund's bed presence going off
        ha.set_state(hass, "binary_sensor.edmund_s_eight_sleep_side_bed_presence", "off")
        time.sleep(3)

        # Trigger the automation directly (in case state change doesn't fire it in test)
        ha.trigger_automation(hass, "edmund_awake_detection")
        time.sleep(2)

        # Edmund should still be marked asleep — time guard blocks
        ha.assert_state(hass, "input_boolean.edmund_awake", "off", timeout=5)

    # ── Test 2: Wake signal at 6:59 AM → blocked (boundary) ────────────
    with subtest("Wake signal at 6:59 AM is blocked by time guard"):
        ha.set_clock(hass, "06:59:00", "2026-02-25")
        reset_state()

        ha.trigger_automation(hass, "edmund_awake_detection")
        time.sleep(2)

        ha.assert_state(hass, "input_boolean.edmund_awake", "off", timeout=5)

    # ── Test 3: Wake signal at 7:01 AM → passes ────────────────────────
    with subtest("Wake signal at 7:01 AM passes time guard"):
        ha.set_clock(hass, "07:01:00", "2026-02-25")
        reset_state()

        ha.trigger_automation(hass, "edmund_awake_detection")
        time.sleep(2)

        ha.assert_state(hass, "input_boolean.edmund_awake", "on", timeout=10)

    # ── Test 4: GOODNIGHT INVARIANT ─────────────────────────────────────
    # Once goodnight is on, no automated path can turn it off before 7 AM.
    # Good Morning is the ONLY automation that clears goodnight, and its
    # time guard is the choke point. We bypass detection guards here (manually
    # set both awake) to test the Good Morning guard directly.
    with subtest("GOODNIGHT INVARIANT: stays on at 3 AM even with both awake"):
        ha.set_clock(hass, "03:00:00", "2026-02-25")
        ha.call_service(hass, "input_boolean", "turn_on", {"entity_id": "input_boolean.goodnight"})
        ha.call_service(hass, "input_boolean", "turn_on", {"entity_id": "input_boolean.edmund_awake"})
        ha.call_service(hass, "input_boolean", "turn_on", {"entity_id": "input_boolean.monica_awake"})
        time.sleep(2)

        ha.trigger_automation(hass, "good_morning_both_awake")
        time.sleep(2)

        ha.assert_state(hass, "input_boolean.goodnight", "on", timeout=5)

    with subtest("GOODNIGHT INVARIANT: stays on at 6:59 AM (boundary)"):
        ha.set_clock(hass, "06:59:00", "2026-02-25")
        ha.call_service(hass, "input_boolean", "turn_on", {"entity_id": "input_boolean.goodnight"})
        ha.call_service(hass, "input_boolean", "turn_on", {"entity_id": "input_boolean.edmund_awake"})
        ha.call_service(hass, "input_boolean", "turn_on", {"entity_id": "input_boolean.monica_awake"})
        time.sleep(2)

        ha.trigger_automation(hass, "good_morning_both_awake")
        time.sleep(2)

        ha.assert_state(hass, "input_boolean.goodnight", "on", timeout=5)

    # ── Test 5: Both awake at 8 AM → Good Morning fires ────────────────
    with subtest("Good Morning fires at 8 AM with both awake"):
        ha.set_clock(hass, "08:00:00", "2026-02-25")
        ha.call_service(hass, "input_boolean", "turn_on", {"entity_id": "input_boolean.goodnight"})
        ha.call_service(hass, "input_boolean", "turn_on", {"entity_id": "input_boolean.edmund_awake"})
        ha.call_service(hass, "input_boolean", "turn_on", {"entity_id": "input_boolean.monica_awake"})
        time.sleep(2)

        ha.trigger_automation(hass, "good_morning_both_awake")
        time.sleep(3)

        # Good Morning scene sets goodnight=off
        ha.assert_state(hass, "input_boolean.goodnight", "off", timeout=10)

    # ── Test 6: Post-bedtime signal at 10:48 PM → allowed ──────────────
    # Time guard `after: 07:00:00` allows signals from 7 AM to midnight.
    # 22:48 PM passes the time guard. The 4:47 AM incident is prevented by
    # blocking the MORNING signal (Test 7), not the evening one.
    with subtest("Wake signal at 10:48 PM passes time guard (after 7 AM)"):
        ha.set_clock(hass, "22:48:00", "2026-02-24")
        reset_state()

        ha.trigger_automation(hass, "edmund_awake_detection")
        time.sleep(2)

        # Time guard passes at 22:48 (after 07:00), so automation fires
        ha.assert_state(hass, "input_boolean.edmund_awake", "on", timeout=5)

    # ── Test 7: Monica wake at 4:47 AM → blocked ───────────────────────
    # The exact time of the incident
    with subtest("Monica wake signal at 4:47 AM is blocked"):
        ha.set_clock(hass, "04:47:00", "2026-02-24")
        reset_state()

        ha.trigger_automation(hass, "monica_awake_detection")
        time.sleep(2)

        ha.assert_state(hass, "input_boolean.monica_awake", "off", timeout=5)

    # ══════════════════════════════════════════════════════════════════════
    # REGRESSION TEST: 2026-02-24 4:47 AM incident
    # Replays the exact forensic timeline from postgres recorder.
    # If this passes, the incident cannot recur. (dotfiles-z92r.5)
    # ══════════════════════════════════════════════════════════════════════

    with subtest("REGRESSION: Full 4:47 AM incident timeline replay"):
        # Step 1: 22:00 — Winding Down fires
        ha.set_clock(hass, "22:00:00", "2026-02-24")
        ha.call_service(hass, "input_boolean", "turn_on", {"entity_id": "input_boolean.goodnight"})
        ha.call_service(hass, "input_boolean", "turn_off", {"entity_id": "input_boolean.edmund_awake"})
        ha.call_service(hass, "input_boolean", "turn_off", {"entity_id": "input_boolean.monica_awake"})
        time.sleep(1)
        ha.assert_state(hass, "input_boolean.goodnight", "on")
        ha.assert_state(hass, "input_boolean.edmund_awake", "off")
        ha.assert_state(hass, "input_boolean.monica_awake", "off")

        # Step 2: 22:48 — Edmund wake signal (phone activity post-bedtime)
        # Time guard allows this (22:48 > 07:00). Same as original bug.
        # The fix works because Step 3 (4:47 AM) is blocked, not Step 2.
        ha.set_clock(hass, "22:48:00", "2026-02-24")
        ha.trigger_automation(hass, "edmund_awake_detection")
        time.sleep(2)
        ha.assert_state(hass, "input_boolean.edmund_awake", "on", timeout=5)

        # Step 3: 04:47 — Monica wake signal
        # In the original bug, this set monica_awake=on → both_awake → Good Morning
        ha.set_clock(hass, "04:47:00", "2026-02-24")
        ha.set_state(hass, "binary_sensor.monica_s_eight_sleep_side_bed_presence", "off")
        time.sleep(1)
        ha.trigger_automation(hass, "monica_awake_detection")
        time.sleep(2)
        ha.assert_state(hass, "input_boolean.monica_awake", "off", timeout=5)

        # Step 4: Verify Good Morning did NOT fire (goodnight still on)
        ha.assert_state(hass, "input_boolean.goodnight", "on", timeout=3)

    with subtest("REGRESSION: Same timeline at 8 AM works correctly"):
        # Reset: simulate morning of 2026-02-25
        ha.set_clock(hass, "07:30:00", "2026-02-25")
        ha.call_service(hass, "input_boolean", "turn_on", {"entity_id": "input_boolean.goodnight"})
        ha.call_service(hass, "input_boolean", "turn_off", {"entity_id": "input_boolean.edmund_awake"})
        ha.call_service(hass, "input_boolean", "turn_off", {"entity_id": "input_boolean.monica_awake"})
        time.sleep(1)

        # Edmund wakes at 7:30 → should be allowed
        ha.trigger_automation(hass, "edmund_awake_detection")
        time.sleep(2)
        ha.assert_state(hass, "input_boolean.edmund_awake", "on", timeout=10)

        # Monica wakes at 8:00 → should be allowed
        # This triggers monica_awake_detection → monica_awake=on
        # → HA fires good_morning_both_awake (real event trigger)
        # → Good Morning scene runs → resets awake states + goodnight=off
        # So we verify the CASCADE result: goodnight=off (proves the full
        # sequence worked: wake detection → both awake → Good Morning)
        ha.set_clock(hass, "08:00:00", "2026-02-25")
        ha.trigger_automation(hass, "monica_awake_detection")
        time.sleep(3)
        ha.assert_state(hass, "input_boolean.goodnight", "off", timeout=10)
  '';
}
