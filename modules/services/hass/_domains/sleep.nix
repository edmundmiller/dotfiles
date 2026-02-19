# Sleep domain — bed presence detection, sleep scenes
{ lib, ... }:
{
  services.home-assistant.config = {
    scene = lib.mkAfter [
      {
        name = "Sleep";
        icon = "mdi:sleep";
        entities = {
          "input_boolean.goodnight" = "on";
          "input_select.house_mode" = "Night";
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
