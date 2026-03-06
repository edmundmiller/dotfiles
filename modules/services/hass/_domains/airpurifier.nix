# Air purifier domain — occupancy-based control
#
# Devices:
#   fan.zhimi_airpurifier_mb3   — Living Room Air Purifier (192.168.1.150)
#   fan.zhimi_airpurifier_mb3_2 — Office Air Purifier (192.168.1.149)
#
# Living room: off when everyone leaves home, on when first person arrives
# Office: binary_sensor.office_occupancy (Ecobee sensor)
{ lib, ... }:
let
  inherit (import ../_lib.nix) ensureEnabled;
in
{
  services.home-assistant.config = {
    homeassistant.customize = {
      "fan.zhimi_airpurifier_mb3" = {
        friendly_name = "Living Room Air Purifier";
      };
      "fan.zhimi_airpurifier_mb3_2" = {
        friendly_name = "Office Air Purifier";
      };
    };

    automation = lib.mkAfter (ensureEnabled [
      {
        alias = "Living Room Purifier Off - Everyone Away";
        id = "living_room_purifier_off_everyone_away";
        description = "Turn off living room air purifier when everyone leaves home";
        trigger = [
          {
            platform = "state";
            entity_id = "person.edmund_miller";
            to = "not_home";
          }
          {
            platform = "state";
            entity_id = "person.moni";
            to = "not_home";
          }
        ];
        condition = [
          {
            condition = "state";
            entity_id = "person.edmund_miller";
            state = "not_home";
          }
          {
            condition = "state";
            entity_id = "person.moni";
            state = "not_home";
          }
        ];
        action = [
          {
            action = "fan.turn_off";
            target.entity_id = "fan.zhimi_airpurifier_mb3";
          }
        ];
      }

      {
        alias = "Living Room Purifier On - Someone Arrives";
        id = "living_room_purifier_on_someone_arrives";
        description = "Turn on living room air purifier when first person arrives home";
        trigger = [
          {
            platform = "state";
            entity_id = "person.edmund_miller";
            to = "home";
          }
          {
            platform = "state";
            entity_id = "person.moni";
            to = "home";
          }
        ];
        action = [
          {
            action = "fan.turn_on";
            target.entity_id = "fan.zhimi_airpurifier_mb3";
          }
        ];
      }
      {
        alias = "Office Purifier Off - Unoccupied";
        id = "office_purifier_off_unoccupied";
        description = "Turn off office air purifier when Ecobee reports no occupancy";
        trigger = {
          platform = "state";
          entity_id = "binary_sensor.office_occupancy";
          to = "off";
          for.minutes = 5;
        };
        action = [
          {
            action = "fan.turn_off";
            target.entity_id = "fan.zhimi_airpurifier_mb3_2";
          }
        ];
      }

      {
        alias = "Office Purifier On - Occupied";
        id = "office_purifier_on_occupied";
        description = "Turn on office air purifier when Ecobee detects occupancy";
        trigger = {
          platform = "state";
          entity_id = "binary_sensor.office_occupancy";
          to = "on";
        };
        action = [
          {
            action = "fan.turn_on";
            target.entity_id = "fan.zhimi_airpurifier_mb3_2";
          }
        ];
      }
    ]);
  };
}
