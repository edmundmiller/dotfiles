# Sleep domain — bed presence detection, sleep/wake routines
{ lib, ... }:
{
  services.home-assistant.config = {
    scene = lib.mkAfter [
      {
        name = "Sleep";
        icon = "mdi:sleep";
        entities = {
          # Modes
          "input_boolean.goodnight" = "on";
          "input_select.house_mode" = "Night";

          # Bedroom — white noise on, blinds closed
          "switch.eve_energy_20ebu4101" = "on"; # Whitenoise Machine
          "cover.smartwings_window_covering" = "closed";

          # Lights off
          "light.essentials_a19_a60" = "off"; # Trashcan
          "light.essentials_a19_a60_2" = "off"; # Dishwasher
          "light.smart_night_light_w" = "off"; # Night Light
          "light.nanoleaf_multicolor_floor_lamp" = "off"; # Couch Lamp
          "light.nanoleaf_multicolor_hd_ls" = "off"; # Edmund Desk

          # Media off
          "media_player.tv" = "off";
        };
      }
    ];

    automation = lib.mkAfter [
      # TODO: Rework this to first activate "Goodnight" scene on bed presence,
      # then randomly 2–5 minutes later activate "Sleep" scene.
      {
        alias = "Bed presence - activate sleep scene";
        id = "bed_presence_sleep";
        trigger = {
          platform = "state";
          entity_id = "binary_sensor.monica_s_eight_sleep_side_bed_presence";
          to = "on";
          "for".minutes = 2;
        };
        action = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.sleep";
          }
        ];
      }
    ];
  };
}
