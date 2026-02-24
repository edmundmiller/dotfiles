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
#   4. Both awake set at 3 AM → Good Morning does NOT fire
#   5. Both awake at 8 AM → Good Morning fires
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

      virtualisation.memorySize = 2048;
    };

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
        """Reset to bedtime preconditions."""
        ha.set_state(hass, "input_boolean.goodnight", "on")
        ha.set_state(hass, "input_boolean.edmund_awake", "off")
        ha.set_state(hass, "input_boolean.monica_awake", "off")
        time.sleep(1)

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

    # ── Test 4: Both awake at 3 AM → Good Morning blocked ──────────────
    with subtest("Good Morning does NOT fire at 3 AM even with both awake"):
        ha.set_clock(hass, "03:00:00", "2026-02-25")
        # Manually set both awake (bypassing their own time guards)
        ha.set_state(hass, "input_boolean.goodnight", "on")
        ha.set_state(hass, "input_boolean.edmund_awake", "on")
        ha.set_state(hass, "input_boolean.monica_awake", "on")
        time.sleep(2)

        # Good Morning automation has its own time guard
        ha.trigger_automation(hass, "good_morning_both_awake")
        time.sleep(2)

        # Goodnight should still be on (Good Morning scene turns it off)
        ha.assert_state(hass, "input_boolean.goodnight", "on", timeout=5)

    # ── Test 5: Both awake at 8 AM → Good Morning fires ────────────────
    with subtest("Good Morning fires at 8 AM with both awake"):
        ha.set_clock(hass, "08:00:00", "2026-02-25")
        ha.set_state(hass, "input_boolean.goodnight", "on")
        ha.set_state(hass, "input_boolean.edmund_awake", "on")
        ha.set_state(hass, "input_boolean.monica_awake", "on")
        time.sleep(2)

        ha.trigger_automation(hass, "good_morning_both_awake")
        time.sleep(3)

        # Good Morning scene sets goodnight=off
        ha.assert_state(hass, "input_boolean.goodnight", "off", timeout=10)

    # ── Test 6: Post-bedtime signal at 10:48 PM → blocked ──────────────
    # This is the actual bug scenario: signal after Winding Down
    with subtest("Wake signal at 10:48 PM (post-bedtime) is blocked"):
        ha.set_clock(hass, "22:48:00", "2026-02-24")
        reset_state()

        # Edmund's phone reports activity (the trigger that caused the incident)
        ha.set_state(hass, "sensor.edmunds_iphone_last_update_trigger", "Launch")
        time.sleep(2)

        ha.trigger_automation(hass, "edmund_awake_detection")
        time.sleep(2)

        ha.assert_state(hass, "input_boolean.edmund_awake", "off", timeout=5)

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
        ha.set_state(hass, "input_boolean.goodnight", "on")
        ha.set_state(hass, "input_boolean.edmund_awake", "off")
        ha.set_state(hass, "input_boolean.monica_awake", "off")
        time.sleep(1)
        ha.assert_state(hass, "input_boolean.goodnight", "on")
        ha.assert_state(hass, "input_boolean.edmund_awake", "off")
        ha.assert_state(hass, "input_boolean.monica_awake", "off")

        # Step 2: 22:48 — Edmund wake signal (phone activity post-bedtime)
        # In the original bug, this set edmund_awake=on. Now it must be blocked.
        ha.set_clock(hass, "22:48:00", "2026-02-24")
        ha.set_state(hass, "sensor.edmunds_iphone_last_update_trigger", "Launch")
        time.sleep(1)
        ha.trigger_automation(hass, "edmund_awake_detection")
        time.sleep(2)
        ha.assert_state(hass, "input_boolean.edmund_awake", "off", timeout=5)

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
        ha.set_state(hass, "input_boolean.goodnight", "on")
        ha.set_state(hass, "input_boolean.edmund_awake", "off")
        ha.set_state(hass, "input_boolean.monica_awake", "off")
        time.sleep(1)

        # Edmund wakes at 7:30 → should be allowed
        ha.trigger_automation(hass, "edmund_awake_detection")
        time.sleep(2)
        ha.assert_state(hass, "input_boolean.edmund_awake", "on", timeout=10)

        # Monica wakes at 8:00 → should be allowed
        ha.set_clock(hass, "08:00:00", "2026-02-25")
        ha.trigger_automation(hass, "monica_awake_detection")
        time.sleep(2)
        ha.assert_state(hass, "input_boolean.monica_awake", "on", timeout=10)

        # Both awake → Good Morning should fire
        ha.trigger_automation(hass, "good_morning_both_awake")
        time.sleep(3)
        ha.assert_state(hass, "input_boolean.goodnight", "off", timeout=10)
  '';
}
