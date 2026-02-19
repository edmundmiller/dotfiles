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

          # Bedroom — white noise on, blinds closed, lights off
          "switch.whitenoise_machine" = "on";
          "cover.smartwings_window_covering" = "closed";
          "light.nightstand" = "off";
          "light.humidifier_light" = "off";
          "light.desk" = "off";
          "light.bedframe" = "off";

          # Entrance
          "light.night_light" = "off";
          "light.forest" = "off";

          # Kitchen
          "light.sink" = "off";

          # Living room
          "light.wall" = "off";
          "light.couch_lamp" = "off";
          "light.christmas_tree" = "off";
          "media_player.tv" = "off";
          "media_player.apple_tv" = "off";

          # Office
          "light.edmund_desk" = "off";
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
