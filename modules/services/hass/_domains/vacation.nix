# Vacation domain — multi-day away mode spanning 8Sleep, Ecobee, lights, blinds
#
# Activation: manually set input_select.house_mode = "Vacation" (dashboard / voice)
# Deactivation: first person arrives home (presence) OR manually set mode back to Home
#
# What vacation mode controls:
#   8Sleep:  away_mode_start (both sides) — suspends alarms, reduces heating
#   Ecobee:  away preset — energy-saving setpoints for the duration
#   Lights:  all off
#   Blinds:  closed
#   TV/media: off
#
# What it does NOT override:
#   Last-person-leaves automation (patched in ambient.nix to skip during Vacation)
#
# Entity TODOs (verify in HA dev-tools → States):
#   Ecobee climate: climate.ecobee  (or whatever the thermostat is named)
#   8Sleep sensors: sensor.edmund_s_eight_sleep_side_sleep_stage
#                   sensor.monica_s_eight_sleep_side_sleep_stage
{ lib, ... }:
let
  allLights = [
    "light.essentials_a19_a60"
    "light.essentials_a19_a60_2"
    "light.essentials_a19_a60_3"
    "light.essentials_a19_a60_4"
    "light.nanoleaf_multicolor_floor_lamp"
    "light.nanoleaf_multicolor_hd_ls"
    "light.smart_night_light_w"
  ];

  vacationStart = [
    # 8Sleep — away mode both sides
    {
      action = "eight_sleep.away_mode_start";
      target.entity_id = "sensor.edmund_s_eight_sleep_side_sleep_stage";
    }
    {
      action = "eight_sleep.away_mode_start";
      target.entity_id = "sensor.monica_s_eight_sleep_side_sleep_stage";
    }
    # Ecobee — switch to away preset (energy-saving setpoints)
    # TODO: verify entity_id; use ecobee.resume_program on return
    {
      action = "climate.set_preset_mode";
      target.entity_id = "climate.ecobee"; # TODO: verify
      data.preset_mode = "away";
    }
    # Lights, blinds, media
    {
      action = "light.turn_off";
      target.entity_id = allLights;
    }
    {
      action = "cover.close_cover";
      target.entity_id = "cover.smartwings_window_covering";
    }
    {
      action = "media_player.turn_off";
      target.entity_id = "media_player.tv";
    }
    {
      action = "switch.turn_off";
      target.entity_id = "switch.eve_energy_20ebu4101";
    }
  ];

  vacationEnd = [
    # 8Sleep — stop away mode both sides
    {
      action = "eight_sleep.away_mode_stop";
      target.entity_id = "sensor.edmund_s_eight_sleep_side_sleep_stage";
    }
    {
      action = "eight_sleep.away_mode_stop";
      target.entity_id = "sensor.monica_s_eight_sleep_side_sleep_stage";
    }
    # Ecobee — resume normal schedule
    {
      action = "ecobee.resume_program";
      target.entity_id = "climate.ecobee"; # TODO: verify
      data.resume_all = true;
    }
    # Welcome home scene handles lights + mode
    {
      action = "scene.turn_on";
      target.entity_id = "scene.arrive_home";
    }
  ];
in
{
  services.home-assistant.config = {
    scene = lib.mkAfter [
      {
        name = "Vacation";
        icon = "mdi:airplane";
        entities = {
          "input_select.house_mode" = "Vacation";
          "cover.smartwings_window_covering" = "closed";
          "light.essentials_a19_a60" = "off";
          "light.essentials_a19_a60_2" = "off";
          "light.essentials_a19_a60_3" = "off";
          "light.essentials_a19_a60_4" = "off";
          "light.nanoleaf_multicolor_floor_lamp" = "off";
          "light.nanoleaf_multicolor_hd_ls" = "off";
          "light.smart_night_light_w" = "off";
          "media_player.tv" = "off";
          "switch.eve_energy_20ebu4101" = "off";
        };
      }
    ];

    automation = lib.mkAfter [
      # Vacation starts — scene activates everything via mode change
      {
        alias = "Vacation Start";
        id = "vacation_start";
        description = "house_mode → Vacation: 8Sleep away, Ecobee away, everything off";
        trigger = {
          platform = "state";
          entity_id = "input_select.house_mode";
          to = "Vacation";
        };
        action = vacationStart;
      }

      # Vacation ends — first person home while in Vacation mode
      {
        alias = "Vacation End - Person Arrives";
        id = "vacation_end_presence";
        description = "First person home during vacation → restore 8Sleep, Ecobee, Welcome Home";
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
        condition = [
          {
            condition = "state";
            entity_id = "input_select.house_mode";
            state = "Vacation";
          }
        ];
        action = vacationEnd;
      }
    ];
  };
}
