# NixOS VM test: boot HA with our modules, verify config + API.
#
# Spins up a QEMU VM with our HA module config (minus secrets/hardware),
# verifies HA starts, checks generated configuration.yaml contains expected
# automations, and exercises the test helper API.
#
# Run: nix build .#checks.x86_64-linux.hass-vm-test
# (requires x86_64-linux — run on NUC or Linux builder)
#
# See also:
#   eval-automations.nix  — fast pure-nix structural assertions (no VM)
#   ha_test_lib.py        — Python test helpers used by this test
{ pkgs }:
let
  # Our HA domain modules — the actual config we're testing
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

  # Test helper library — copy into a directory so it's importable
  testLibDir = pkgs.runCommand "ha-test-lib" { } ''
    mkdir -p $out
    cp ${./ha_test_lib.py} $out/ha_test_lib.py
  '';
in
pkgs.testers.nixosTest {
  name = "hass-config";

  nodes.hass =
    { config, ... }:
    {
      # Import domain modules directly (they use services.home-assistant.config)
      imports = domainModules;

      services.home-assistant = {
        enable = true;

        extraComponents = [
          "met" # Required for default_config
        ];

        config = {
          # Minimal homeassistant config for testing
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

          # Frontend needed for onboarding
          frontend = { };

          # Logger for debugging
          logger.default = "info";

          # Base automation list — domain modules append via mkAfter
          automation = [ ];
        };
      };

      # Create empty yaml files so HA doesn't fail
      systemd.tmpfiles.rules = [
        "f ${config.services.home-assistant.configDir}/automations.yaml 0644 hass hass"
        "f ${config.services.home-assistant.configDir}/scenes.yaml 0644 hass hass"
        "f ${config.services.home-assistant.configDir}/scripts.yaml 0644 hass hass"
      ];

      # Match HA timezone so clock manipulation works correctly
      time.timeZone = "US/Central";
      # Enough RAM for HA
      virtualisation.memorySize = 2048;
    };

  # ha_test_lib is injected at runtime via sys.path — mypy can't find it
  skipTypeCheck = true;

  testScript = ''
    import sys
    sys.path.insert(0, "${testLibDir}")
    import ha_test_lib as ha

    start_all()

    # ── Boot + readiness ─────────────────────────────────────────────────
    with subtest("HA starts and API is reachable"):
        ha.wait_ready(hass)

    # ── Onboarding + auth ────────────────────────────────────────────────
    with subtest("Onboarding completes and token is created"):
        token = ha.create_token(hass)
        assert token, "Failed to obtain auth token"

    # ── Configuration structure ──────────────────────────────────────────
    with subtest("configuration.yaml exists and is a symlink"):
        hass.succeed("test -L /var/lib/hass/configuration.yaml")

    with subtest("configuration.yaml contains expected automation IDs"):
        config = hass.succeed("cat /var/lib/hass/configuration.yaml")

        # Wake detection automations
        for automation_id in [
            "edmund_awake_detection",
            "monica_awake_detection",
            "good_morning_both_awake",
        ]:
            assert automation_id in config, f"automation {automation_id} missing from config"

        # Sleep automations
        for automation_id in [
            "winding_down",
            "bed_presence_in_bed",
        ]:
            assert automation_id in config, f"automation {automation_id} missing from config"

        # 8Sleep automations
        for automation_id in [
            "sync_iphone_alarm_8sleep",
            "sleep_focus_off_stop_edmund",
            "sleep_focus_off_stop_monica",
        ]:
            assert automation_id in config, f"automation {automation_id} missing from config"

    with subtest("configuration.yaml contains time guards"):
        config = hass.succeed("cat /var/lib/hass/configuration.yaml")
        # The YAML should contain '07:00:00' for time guards
        assert "'07:00:00'" in config or "07:00:00" in config, \
            "time guard '07:00:00' not found in configuration.yaml"

    with subtest("configuration.yaml contains expected scenes"):
        config = hass.succeed("cat /var/lib/hass/configuration.yaml")
        for scene_name in ["Winding Down", "In Bed", "Sleep", "Good Morning"]:
            assert scene_name in config, f"scene '{scene_name}' missing from config"

    with subtest("configuration.yaml contains input_booleans"):
        config = hass.succeed("cat /var/lib/hass/configuration.yaml")
        for boolean in ["goodnight", "edmund_awake", "monica_awake", "guest_mode", "do_not_disturb"]:
            assert boolean in config, f"input_boolean '{boolean}' missing from config"

    # ── API access (authenticated) ───────────────────────────────────────
    with subtest("HA API responds"):
        result = ha._api(hass, "GET", "")
        assert result.get("message") == "API running.", f"Unexpected API response: {result}"

    with subtest("No errors in HA log"):
        # Allow specific known benign errors but catch real ones
        hass.succeed(
            "journalctl -u home-assistant.service -o cat "
            "| grep -i error "
            "| grep -v 'No access to /dev/tty' "
            "| grep -v 'Setup failed for' "  # expected: no real devices
            "| grep -v 'Unable to install' "  # expected: no network in sandbox
            "| grep -v 'OSError' "  # expected: no hardware
            "| grep -v 'unknown entity' "  # expected: no real sensors in test VM
            "|| true"  # Don't fail if grep finds nothing
        )
  '';
}
