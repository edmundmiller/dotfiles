# Home Assistant owns awake climate policy; Ecobee schedules are the fail-safe.
{ lib, ... }:
let
  inherit (import ../_lib.nix) ensureEnabled;

  thermostats = [
    "climate.main_floor"
    "climate.master_suite"
  ];

  clearHoldButtons = [
    "button.main_floor_clear_hold"
    "button.master_suite_clear_hold"
  ];
in
{
  services.home-assistant.config = {
    input_number.occupied_cooling_target = {
      name = "Occupied Cooling Target";
      icon = "mdi:snowflake-thermometer";
      min = 68;
      max = 76;
      step = 0.5;
      initial = 72;
      unit_of_measurement = "F";
    };

    timer.climate_policy_hold = {
      name = "Climate Policy Hold";
      duration = "00:45:00";
      restore = true;
    };

    rest = lib.mkAfter [
      {
        resource = "https://www.ercot.com/api/1/services/read/dashboards/daily-prc.json";
        scan_interval = 300;
        timeout = 15;
        sensor = [
          {
            name = "ERCOT Grid Status";
            unique_id = "ercot_grid_status";
            icon = "mdi:transmission-tower";
            value_template = "{{ value_json.current_condition.state }}";
            json_attributes = [
              "lastUpdated"
              "current_condition"
            ];
          }
        ];
      }
    ];

    script.apply_climate_policy = {
      alias = "Apply Climate Policy";
      icon = "mdi:home-thermometer";
      mode = "restart";
      sequence = [
        {
          variables = {
            policy_active = ''
              {{ states('input_boolean.goodnight') in ['on', 'off']
                 and states('input_boolean.vacation_mode') in ['on', 'off']
                 and states('person.edmund_miller') not in ['unknown', 'unavailable']
                 and states('person.moni') not in ['unknown', 'unavailable']
                 and is_state('input_boolean.goodnight', 'off')
                 and not is_state('binary_sensor.eve_door_20ebn9901_door', 'on') }}
            '';
            target_temperature = ''
              {% set base = states('input_number.occupied_cooling_target') | float(72) %}
              {% set occupied = is_state('person.edmund_miller', 'home')
                                or is_state('person.moni', 'home') %}
              {% set condition = state_attr('sensor.ercot_grid_status', 'current_condition') or {} %}
              {% set ercot_fresh = as_timestamp(
                   state_attr('sensor.ercot_grid_status', 'lastUpdated'), 0
                 ) > now().timestamp() - 900 %}
              {% set grid_stressed = ercot_fresh
                   and (states('sensor.ercot_grid_status') != 'normal'
                        or condition.get('eea_level', 0) | int(0) > 0) %}
              {% set humidity_high =
                   states('sensor.main_floor_current_humidity') | float(0) > 60
                   or states('sensor.master_suite_current_humidity') | float(0) > 60 %}
              {% if is_state('input_boolean.vacation_mode', 'on') or not occupied %}
                78
              {% elif grid_stressed %}
                {{ [base, 74] | max }}
              {% elif humidity_high %}
                {{ [base, 71.5] | min }}
              {% else %}
                {{ base }}
              {% endif %}
            '';
          };
        }
        {
          choose = [
            {
              conditions = [
                {
                  condition = "template";
                  value_template = "{{ policy_active }}";
                }
              ];
              sequence = [
                {
                  "if" = [
                    {
                      condition = "template";
                      value_template = ''
                        {{ states('climate.main_floor') != 'cool'
                           or states('climate.master_suite') != 'cool' }}
                      '';
                    }
                  ];
                  "then" = [
                    {
                      action = "climate.set_hvac_mode";
                      target.entity_id = thermostats;
                      data.hvac_mode = "cool";
                    }
                  ];
                }
                {
                  "if" = [
                    {
                      condition = "template";
                      value_template = ''
                        {{ (state_attr('climate.main_floor', 'temperature') | float(0)
                            - target_temperature | float) | abs > 0.4
                           or (state_attr('climate.master_suite', 'temperature') | float(0)
                               - target_temperature | float) | abs > 0.4 }}
                      '';
                    }
                  ];
                  "then" = [
                    {
                      action = "climate.set_temperature";
                      target.entity_id = thermostats;
                      data.temperature = "{{ target_temperature | float }}";
                    }
                  ];
                }
                {
                  action = "timer.start";
                  target.entity_id = "timer.climate_policy_hold";
                }
              ];
            }
          ];
          default = [
            {
              action = "timer.cancel";
              target.entity_id = "timer.climate_policy_hold";
            }
            {
              action = "button.press";
              target.entity_id = clearHoldButtons;
            }
          ];
        }
      ];
    };

    automation = lib.mkAfter (ensureEnabled [
      {
        alias = "Climate policy";
        id = "climate_policy";
        description = "Apply bounded awake targets; sleep and invalid core state resume Ecobee schedules.";
        mode = "restart";
        trigger = [
          {
            platform = "homeassistant";
            event = "start";
          }
          {
            platform = "time_pattern";
            minutes = "/15";
          }
          {
            platform = "state";
            entity_id = [
              "person.edmund_miller"
              "person.moni"
              "input_boolean.goodnight"
              "input_boolean.vacation_mode"
              "sensor.ercot_grid_status"
            ];
          }
          {
            platform = "numeric_state";
            entity_id = [
              "sensor.main_floor_current_humidity"
              "sensor.master_suite_current_humidity"
            ];
            above = 60;
          }
          {
            platform = "numeric_state";
            entity_id = [
              "sensor.main_floor_current_humidity"
              "sensor.master_suite_current_humidity"
            ];
            below = 58;
          }
        ];
        action = [
          {
            action = "script.apply_climate_policy";
          }
        ];
      }
      {
        alias = "Climate hold watchdog";
        id = "climate_hold_watchdog";
        description = "Clear each HA hold after 45 minutes, then re-evaluate instead of leaving an indefinite hold.";
        trigger = {
          platform = "event";
          event_type = "timer.finished";
          event_data.entity_id = "timer.climate_policy_hold";
        };
        action = [
          {
            action = "button.press";
            target.entity_id = clearHoldButtons;
          }
          {
            delay.seconds = 5;
          }
          {
            action = "script.apply_climate_policy";
          }
        ];
      }
      {
        alias = "Pause climate when front door stays open";
        id = "climate_pause_front_door_open";
        description = "Pause cooling after the front door remains open for five minutes.";
        trigger = {
          platform = "state";
          entity_id = "binary_sensor.eve_door_20ebn9901_door";
          to = "on";
          "for".minutes = 5;
        };
        action = [
          {
            action = "timer.cancel";
            target.entity_id = "timer.climate_policy_hold";
          }
          {
            action = "button.press";
            target.entity_id = clearHoldButtons;
          }
          {
            action = "climate.set_hvac_mode";
            target.entity_id = thermostats;
            data.hvac_mode = "off";
          }
        ];
      }
      {
        alias = "Resume climate when front door closes";
        id = "climate_resume_front_door_closed";
        description = "Re-evaluate the climate policy when the front door closes.";
        trigger = {
          platform = "state";
          entity_id = "binary_sensor.eve_door_20ebn9901_door";
          to = "off";
        };
        action = [
          {
            action = "script.apply_climate_policy";
          }
        ];
      }
    ]);
  };
}
