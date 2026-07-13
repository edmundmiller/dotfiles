# Vacation domain — multi-day away mode spanning 8Sleep, Ecobee, lights, blinds
#
# Activation: turn on input_boolean.vacation_mode (dashboard / voice)
# Deactivation: first person arrives home (presence) OR manually set mode back to Home
#
# What vacation mode controls:
#   8Sleep:  away_mode_start (both sides) — suspends alarms, reduces heating
#   Thermostats: energy-saving cooling setpoints for the duration
#   Lights:  all off
#   Blinds:  closed
#   TV/media: off
#
# What it does NOT override:
#   Last-person-leaves automation (patched in ambient.nix to skip during Vacation)
#
# Climate policy owns `climate.main_floor`, `climate.master_suite`, and both clear-hold buttons.
# 8Sleep sensors: sensor.edmund_s_eight_sleep_side_sleep_stage
#                     sensor.monica_s_eight_sleep_side_sleep_stage
{ lib, ... }:
let
  inherit (import ../_lib.nix) ensureEnabled;

  vacationStart = [
    # Entity state changes — delegated to scene (lights, blinds, media, mode)
    {
      action = "scene.turn_on";
      target.entity_id = "scene.vacation";
    }
    {
      action = "script.tv_off_if_on";
    }
    # Service calls that scenes can't express:
    # 8Sleep — away mode both sides
    {
      action = "eight_sleep.away_mode_start";
      target.entity_id = "sensor.edmund_s_eight_sleep_side_sleep_stage";
    }
    {
      action = "eight_sleep.away_mode_start";
      target.entity_id = "sensor.monica_s_eight_sleep_side_sleep_stage";
    }
    # Thermostats — apply the HA-owned 78°F vacation target with hold watchdog
    {
      action = "script.apply_climate_policy";
    }
  ];

  vacationEnd = [
    {
      action = "input_boolean.turn_off";
      target.entity_id = "input_boolean.vacation_mode";
    }
    # 8Sleep — stop away mode both sides
    {
      action = "eight_sleep.away_mode_stop";
      target.entity_id = "sensor.edmund_s_eight_sleep_side_sleep_stage";
    }
    {
      action = "eight_sleep.away_mode_stop";
      target.entity_id = "sensor.monica_s_eight_sleep_side_sleep_stage";
    }
    # Release the vacation hold before recalculating occupied policy.
    {
      action = "button.press";
      target.entity_id = [
        "button.main_floor_clear_hold"
        "button.master_suite_clear_hold"
      ];
    }
    {
      action = "script.apply_climate_policy";
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
    input_boolean.vacation_mode = {
      name = "Vacation Mode";
      icon = "mdi:airplane";
    };

    scene = lib.mkAfter [
      {
        name = "Vacation";
        icon = "mdi:airplane";
        entities = {
          "input_boolean.vacation_mode" = "on";
          "cover.smartwings_window_covering" = "closed";
          "light.essentials_a19_a60" = "off";
          "light.essentials_a19_a60_2" = "off";
          "light.essentials_a19_a60_3" = "off";
          "light.essentials_a19_a60_4" = "off";
          "light.nanoleaf_multicolor_floor_lamp" = "off";
          "light.nanoleaf_multicolor_hd_ls" = "off";
          "light.smart_night_light_w" = "off";
          "switch.eve_energy_20ebu4101" = "off";
        };
      }
    ];

    automation = lib.mkAfter (ensureEnabled [
      # Vacation starts — scene activates everything via mode change
      {
        alias = "Vacation Start";
        id = "vacation_start";
        description = "vacation_mode on: 8Sleep away, thermostat away setpoints, everything off";
        trigger = {
          platform = "state";
          entity_id = "input_boolean.vacation_mode";
          to = "on";
        };
        action = vacationStart;
      }

      # Vacation ends — first person home while in Vacation mode
      {
        alias = "Vacation End - Person Arrives";
        id = "vacation_end_presence";
        description = "First person home during vacation -> restore 8Sleep, resume HA climate policy, Welcome Home";
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
            entity_id = "input_boolean.vacation_mode";
            state = "on";
          }
        ];
        action = vacationEnd;
      }
    ]);
  };
}
