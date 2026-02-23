# Lighting domain — Adaptive Lighting (circadian color temperature + brightness)
#
# Adjusts color temp and brightness based on sun position.
# Sleep mode: 9:30 PM time trigger (pre-warmup); on/off also embedded in
# Winding Down and Good Morning scenes (sleep/, modes.nix).
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
          "light.essentials_a19_a60_3" # Bathroom Nightstand
          "light.essentials_a19_a60_4" # Window Nightstand
          "light.nanoleaf_multicolor_floor_lamp" # Couch Lamp
          "light.nanoleaf_multicolor_hd_ls" # Edmund Desk
          "light.smart_night_light_w" # Entrance night light
        ];
        min_brightness = 20;
        max_brightness = 100;
        min_color_temp = 2000; # warm white
        max_color_temp = 5500; # cool daylight
        sleep_brightness = 10;
        sleep_color_temp = 1000;
        # All lights clip at min_color_temp_kelvin=2127K so color_temp alone
        # can't reach 1000K. Switch sleep mode to RGB and send [255, 56, 0]
        # (≈1000K deep warm red) to bypass the hardware color_temp floor.
        sleep_rgb_or_color_temp = "rgb_color";
        sleep_rgb_color = [
          255
          56
          0
        ];
        take_over_control = true;
        detect_non_ha_changes = false;
      }
    ];

    automation = lib.mkAfter [
      # AL sleep mode on: 9:30 PM — 30 min early warmup before Winding Down at 10 PM
      # Goodnight path handled by Winding Down scene
      {
        alias = "Adaptive Lighting: sleep mode on";
        id = "al_sleep_mode_on";
        description = "Enable AL sleep mode at 9:30 PM (30 min pre-warmup before Winding Down)";
        trigger = {
          platform = "time";
          at = "21:30:00";
        };
        action = [
          {
            action = "switch.turn_on";
            target.entity_id = "switch.adaptive_lighting_sleep_mode_living_space";
          }
        ];
      }
      # AL sleep mode off: 7:00 AM hard cutoff
      # Goodnight path handled by Good Morning scene
      {
        alias = "Adaptive Lighting: sleep mode off";
        id = "al_sleep_mode_off";
        description = "Disable AL sleep mode at 7 AM hard cutoff";
        trigger = {
          platform = "time";
          at = "07:00:00";
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
