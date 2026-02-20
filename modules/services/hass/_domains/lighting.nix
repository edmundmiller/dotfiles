# Lighting domain — Adaptive Lighting (circadian color temperature + brightness)
#
# Adjusts color temp and brightness based on sun position.
# Sleep mode integrates with existing goodnight flow.
#
# One switch: "Living Space" — all color-temp-capable lights.
# TODO: Consider splitting office (Edmund Desk) into separate switch
#       if different brightness curves are needed during work hours.
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
          "light.essentials_a19_a60_3" # Left Night Stand
          "light.essentials_a19_a60_4" # Right Nightstand
          "light.nanoleaf_multicolor_floor_lamp" # Couch Lamp
          "light.nanoleaf_multicolor_hd_ls" # Edmund Desk
          "light.smart_night_light_w" # Entrance night light
        ];
        min_brightness = 20;
        max_brightness = 100;
        min_color_temp = 2000; # warm white
        max_color_temp = 5500; # cool daylight
        sleep_brightness = 10;
        sleep_color_temp = 1000; # deep warm red — melatonin-friendly
        take_over_control = true;
        detect_non_ha_changes = false;
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
