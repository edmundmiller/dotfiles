# NixOS VM test: sleep automation behavior after removing auto Good Morning.
#
# Verifies:
#   - Wake detection automations are present
#   - Auto Good Morning automation is absent
#   - Existing bedtime automations (Winding Down) still run
#   - Wake detection can mark awake without triggering Good Morning
#   - Good Morning scene still works manually
#   - AL startup correction regression remains covered
{ pkgs }:
let
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
          default_config = { };
          frontend = { };
          logger.default = "info";
          automation = [ ];
        };
      };

      systemd.tmpfiles.rules = [
        "f ${config.services.home-assistant.configDir}/automations.yaml 0644 hass hass"
        "f ${config.services.home-assistant.configDir}/scenes.yaml 0644 hass hass"
        "f ${config.services.home-assistant.configDir}/scripts.yaml 0644 hass hass"
      ];

      time.timeZone = "US/Central";
      virtualisation.memorySize = 2048;
    };

  skipTypeCheck = true;

  testScript = ''
    import sys
    import time
    sys.path.insert(0, "${testLibDir}")
    import ha_test_lib as ha

    start_all()

    ha.wait_ready(hass)
    ha.create_token(hass)

    with subtest("Wake-detection present, auto Good Morning removed"):
      config = hass.succeed("cat /var/lib/hass/configuration.yaml")
      for automation_id in [
          "edmund_awake_detection",
          "monica_awake_detection",
      ]:
          assert automation_id in config, f"automation {automation_id} missing"

      for automation_id in [
          "good_morning_both_awake",
      ]:
          assert automation_id not in config, f"automation {automation_id} should be removed"
    with subtest("Wake detection marks awake but does not auto-run Good Morning"):
      ha.set_clock(hass, "08:05:00", "2026-03-13")
      ha.call_service(hass, "input_boolean", "turn_on", {"entity_id": "input_boolean.goodnight"})
      ha.call_service(hass, "input_boolean", "turn_off", {"entity_id": "input_boolean.edmund_awake"})
      time.sleep(1)

      ha.trigger_automation(hass, "edmund_awake_detection")
      time.sleep(2)

      ha.assert_state(hass, "input_boolean.edmund_awake", "on", timeout=10)
      ha.assert_state(hass, "input_boolean.goodnight", "on", timeout=10)


    with subtest("Winding Down still auto-runs at 10 PM"):
      ha.set_clock(hass, "21:55:00", "2026-03-12")
      ha.call_service(hass, "input_boolean", "turn_off", {"entity_id": "input_boolean.goodnight"})
      time.sleep(1)

      ha.set_clock(hass, "22:05:00", "2026-03-12")
      time.sleep(3)

      ha.assert_state(hass, "input_boolean.goodnight", "on", timeout=10)

    with subtest("Good Morning scene is still manually callable"):
      ha.call_service(hass, "scene", "turn_on", {"entity_id": "scene.good_morning"})
      time.sleep(2)
      ha.assert_state(hass, "input_boolean.goodnight", "off", timeout=10)

    with subtest("Regression: homeassistant_start clears stale AL sleep mode"):
      ha.set_clock(hass, "10:15:00", "2026-03-09")
      ha.call_service(hass, "input_boolean", "turn_off", {"entity_id": "input_boolean.goodnight"})
      ha.call_service(hass, "switch", "turn_on", {"entity_id": "switch.adaptive_lighting_sleep_mode_living_space"})
      time.sleep(1)
      ha.assert_state(hass, "switch.adaptive_lighting_sleep_mode_living_space", "on", timeout=5)

      ha.fire_event(hass, "homeassistant_start")
      time.sleep(2)

      ha.assert_state(hass, "switch.adaptive_lighting_sleep_mode_living_space", "off", timeout=10)
  '';
}
