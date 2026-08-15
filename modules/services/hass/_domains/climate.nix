# Home Assistant owns climate targets; Ecobee schedules are the fail-safe.
{ lib, ... }:
let
  inherit (import ../_lib.nix) ensureEnabled;

  thermostats = [
    "climate.main_floor"
    "climate.master_suite"
  ];

  people = [
    "person.edmund_miller"
    "person.moni"
  ];

  homeWifiSsids = [
    "sensor.edmunds_iphone_ssid"
    "sensor.monicas_iphone_ssid"
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

    input_number.climate_manual_override_target = {
      name = "Temporary Cooling Target";
      icon = "mdi:thermometer-chevron-up";
      min = 68;
      max = 76;
      step = 0.5;
      unit_of_measurement = "F";
    };

    timer.climate_policy_hold = {
      name = "Climate Policy Hold";
      duration = "00:45:00";
      restore = true;
    };

    timer.climate_manual_override = {
      name = "Temporary Climate Override";
      duration = "02:00:00";
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
                 and (states('person.edmund_miller') not in ['unknown', 'unavailable']
                      or is_state('sensor.edmunds_iphone_ssid', 'Aviato'))
                 and (states('person.moni') not in ['unknown', 'unavailable']
                      or is_state('sensor.monicas_iphone_ssid', 'Aviato'))
                 and not is_state('binary_sensor.eve_door_20ebn9901_door', 'on') }}
            '';
            target_temperature = ''
              {% set base = states('input_number.occupied_cooling_target') | float(72) %}
              {% set away_target = 76 %}
              {% set vacation_target = 78 %}
              {% set occupied = is_state('person.edmund_miller', 'home')
                                or is_state('person.moni', 'home')
                                or is_state('sensor.edmunds_iphone_ssid', 'Aviato')
                                or is_state('sensor.monicas_iphone_ssid', 'Aviato') %}
              {% set latest_presence_change = [
                   as_timestamp(states.person.edmund_miller.last_changed, now().timestamp()),
                   as_timestamp(states.person.moni.last_changed, now().timestamp()),
                   as_timestamp(states.sensor.edmunds_iphone_ssid.last_changed, now().timestamp()),
                   as_timestamp(states.sensor.monicas_iphone_ssid.last_changed, now().timestamp())
                 ] | max %}
              {% set away_long_enough = not occupied
                   and latest_presence_change <= now().timestamp() - 7200 %}
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
              {% if is_state('timer.climate_manual_override', 'active') %}
                {{ states('input_number.climate_manual_override_target') | float(74) }}
              {% elif is_state('input_boolean.vacation_mode', 'on') %}
                {{ vacation_target }}
              {% elif away_long_enough %}
                {{ away_target }}
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
                    {
                      action = "timer.start";
                      target.entity_id = "timer.climate_policy_hold";
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
                    {
                      action = "timer.start";
                      target.entity_id = "timer.climate_policy_hold";
                    }
                  ];
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

    script.activate_climate_manual_override = {
      alias = "Use Temporary Climate Target";
      icon = "mdi:dog-side";
      mode = "restart";
      fields.temperature = {
        name = "Cooling target";
        description = "Ignore automatic humidity and grid adjustments for two hours.";
        required = true;
        default = 74;
        selector.number = {
          min = 68;
          max = 76;
          step = 0.5;
          unit_of_measurement = "F";
          mode = "slider";
        };
      };
      sequence = [
        {
          action = "input_number.set_value";
          target.entity_id = "input_number.climate_manual_override_target";
          data.value = "{{ temperature | float }}";
        }
        {
          action = "timer.start";
          target.entity_id = "timer.climate_manual_override";
        }
        {
          action = "script.apply_climate_policy";
        }
      ];
    };

    automation = lib.mkAfter (ensureEnabled [
      {
        alias = "Climate policy";
        id = "climate_policy";
        description = "Continuously apply bounded targets; combine GPS and home WiFi occupancy; delay ordinary away cooling for two hours; reconcile Ecobee schedule transitions.";
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
            entity_id =
              people
              ++ homeWifiSsids
              ++ [
                "input_boolean.goodnight"
                "input_boolean.vacation_mode"
                "input_number.occupied_cooling_target"
                "sensor.ercot_grid_status"
              ];
          }
          {
            platform = "state";
            entity_id = thermostats;
            attribute = "temperature";
            "for".seconds = 5;
          }
          {
            platform = "state";
            entity_id = people;
            not_to = [
              "home"
              "unknown"
              "unavailable"
            ];
            "for".hours = 2;
          }
          {
            platform = "state";
            entity_id = homeWifiSsids;
            not_to = [
              "Aviato"
              "unknown"
              "unavailable"
            ];
            "for".hours = 2;
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
        description = "Re-evaluate each HA hold after 45 minutes without releasing the active target.";
        trigger = {
          platform = "event";
          event_type = "timer.finished";
          event_data.entity_id = "timer.climate_policy_hold";
        };
        action = [
          {
            action = "script.apply_climate_policy";
          }
        ];
      }
      {
        alias = "Respect HA manual climate target";
        id = "climate_manual_override_detected";
        description = "Follow an authenticated HA thermostat target for two hours; treat anonymous Ecobee schedule changes as drift.";
        mode = "restart";
        trigger = {
          platform = "state";
          entity_id = thermostats;
          attribute = "temperature";
        };
        condition = [
          {
            condition = "template";
            value_template = ''
              {{ trigger.to_state is not none
                 and trigger.to_state.context.parent_id is none
                 and trigger.to_state.context.user_id is not none
                 and trigger.to_state.attributes.temperature is number }}
            '';
          }
        ];
        action = [
          {
            action = "input_number.set_value";
            target.entity_id = "input_number.climate_manual_override_target";
            data.value = "{{ trigger.to_state.attributes.temperature | float }}";
          }
          {
            action = "timer.start";
            target.entity_id = "timer.climate_manual_override";
          }
          {
            action = "timer.cancel";
            target.entity_id = "timer.climate_policy_hold";
          }
          {
            action = "script.apply_climate_policy";
          }
        ];
      }
      {
        alias = "Resume climate policy after manual override";
        id = "climate_manual_override_finished";
        description = "Resume automatic humidity and grid adjustments after the temporary target expires.";
        trigger = {
          platform = "event";
          event_type = "timer.finished";
          event_data.entity_id = "timer.climate_manual_override";
        };
        action = [
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
            action = "button.press";
            target.entity_id = clearHoldButtons;
          }
          {
            action = "climate.set_hvac_mode";
            target.entity_id = thermostats;
            data.hvac_mode = "off";
          }
          {
            action = "timer.start";
            target.entity_id = "timer.climate_policy_hold";
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
