# Lighting domain — Adaptive Lighting (circadian color temperature + brightness)
#
# Adjusts color temp and brightness based on sun position.
# Sleep mode integrates with existing goodnight flow.
#
# Two switches:
#   - "Living Space" — main living area lights (kitchen, living room, entrance)
#   - "Office" — desk lamp (separate so work lighting can differ)
#
# Manual control detection is on — if you manually adjust a light,
# AL stops adapting it until it's toggled off/on.
{ lib, ... }:
{
  services.home-assistant.config = {
    adaptive_lighting = [
      {
        name = "Living Space";
        lights = [
          "light.essentials_a19_a60" # Trashcan (kitchen)
          "light.essentials_a19_a60_2" # Dishwasher (kitchen)
          "light.nanoleaf_multicolor_floor_lamp" # Couch Lamp
          "light.nanoleaf_multicolor_hd_ls" # Edmund Desk (shared w/ office)
          "light.smart_night_light_w" # Entrance night light
        ];
        min_brightness = 20;
        max_brightness = 100;
        min_color_temp = 2000; # warm candlelight
        max_color_temp = 5500; # cool daylight
        sleep_brightness = 5;
        sleep_color_temp = 2000;
        transition = 30;
        take_over_control = true;
        detect_non_ha_changes = false;
        sunrise_offset = 0;
        sunset_offset = 0;
      }
    ];

    automation = lib.mkAfter [
      # Sync AL sleep mode with goodnight toggle
      {
        alias = "Adaptive Lighting: sleep mode on";
        id = "al_sleep_mode_on";
        description = "Enable AL sleep mode when goodnight is toggled on";
        trigger = {
          platform = "state";
          entity_id = "input_boolean.goodnight";
          to = "on";
        };
        action = [
          {
            action = "switch.turn_on";
            target.entity_id = "switch.adaptive_lighting_sleep_mode_living_space";
          }
        ];
      }
      {
        alias = "Adaptive Lighting: sleep mode off";
        id = "al_sleep_mode_off";
        description = "Disable AL sleep mode when goodnight is toggled off (morning)";
        trigger = {
          platform = "state";
          entity_id = "input_boolean.goodnight";
          to = "off";
        };
        action = [
          {
            action = "switch.turn_off";
            target.entity_id = "switch.adaptive_lighting_sleep_mode_living_space";
          }
        ];
      }
    ];
  };
}
