# Ecobee comfort profiles own normal targets; Home Assistant owns profile transitions and exceptions.
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

  climateFailureNotification = "ecobee_climate_transition_failed";
in
{
  services.home-assistant.config = {
    input_number.climate_manual_override_target = {
      name = "Temporary Cooling Target";
      icon = "mdi:thermometer-chevron-up";
      min = 68;
      max = 76;
      step = 0.5;
      unit_of_measurement = "F";
    };

    timer.climate_manual_override = {
      name = "Temporary Climate Override";
      duration = "02:00:00";
      restore = true;
    };

    script.apply_ecobee_profile = {
      alias = "Apply Ecobee Comfort Profile";
      description = "Select one native profile on each Ecobee serially, verify readback, retry once, and report failure.";
      icon = "mdi:thermostat-auto";
      mode = "restart";
      fields = {
        profile = {
          name = "Comfort profile";
          required = true;
          selector.select.options = [
            "home"
            "sleep"
            "away"
          ];
        };
        expected_temperature = {
          name = "Expected cooling target";
          required = true;
          selector.number = {
            min = 68;
            max = 78;
            step = 0.5;
            unit_of_measurement = "F";
          };
        };
      };
      sequence = [
        {
          action = "climate.set_hvac_mode";
          target.entity_id = thermostats;
          data.hvac_mode = "cool";
          continue_on_error = true;
        }
        {
          action = "persistent_notification.dismiss";
          data.notification_id = climateFailureNotification;
          continue_on_error = true;
        }
        {
          repeat = {
            for_each = [
              {
                name = "Main Floor";
                climate = "climate.main_floor";
                selector = "select.main_floor_current_mode";
                clear_hold = "button.main_floor_clear_hold";
              }
              {
                name = "Master Suite";
                climate = "climate.master_suite";
                selector = "select.master_suite_current_mode";
                clear_hold = "button.master_suite_clear_hold";
              }
            ];
            sequence = [
              {
                "if" = [
                  {
                    condition = "template";
                    value_template = ''
                      {{ states(repeat.item.selector) != profile
                         or (state_attr(repeat.item.climate, 'temperature') | float(0)
                             - expected_temperature | float) | abs > 0.4 }}
                    '';
                  }
                ];
                "then" = [
                  {
                    action = "button.press";
                    target.entity_id = "{{ repeat.item.clear_hold }}";
                    continue_on_error = true;
                  }
                  {
                    action = "select.select_option";
                    target.entity_id = "{{ repeat.item.selector }}";
                    data.option = "{{ profile }}";
                    continue_on_error = true;
                  }
                ];
              }
              {
                wait_template = ''
                  {{ states(repeat.item.selector) == profile
                     and (state_attr(repeat.item.climate, 'temperature') | float(0)
                          - expected_temperature | float) | abs <= 0.4 }}
                '';
                timeout.seconds = 60;
                continue_on_timeout = true;
              }
              {
                "if" = [
                  {
                    condition = "template";
                    value_template = "{{ not wait.completed }}";
                  }
                ];
                "then" = [
                  {
                    action = "button.press";
                    target.entity_id = "{{ repeat.item.clear_hold }}";
                    continue_on_error = true;
                  }
                  {
                    action = "select.select_option";
                    target.entity_id = "{{ repeat.item.selector }}";
                    data.option = "{{ profile }}";
                    continue_on_error = true;
                  }
                  {
                    wait_template = ''
                      {{ states(repeat.item.selector) == profile
                         and (state_attr(repeat.item.climate, 'temperature') | float(0)
                              - expected_temperature | float) | abs <= 0.4 }}
                    '';
                    timeout.seconds = 60;
                    continue_on_timeout = true;
                  }
                ];
              }
              {
                "if" = [
                  {
                    condition = "template";
                    value_template = "{{ not wait.completed }}";
                  }
                ];
                "then" = [
                  {
                    action = "persistent_notification.create";
                    data = {
                      notification_id = climateFailureNotification;
                      title = "Ecobee profile change failed";
                      message = "{{ repeat.item.name }} did not reach the {{ profile }} profile at {{ expected_temperature }} F after two attempts.";
                    };
                  }
                ];
              }
            ];
          };
        }
      ];
    };

    script.apply_ecobee_target = {
      alias = "Apply Exceptional Ecobee Target";
      description = "Apply one temporary target to both Ecobees, verify readback, retry once, and report failure.";
      icon = "mdi:thermometer-check";
      mode = "restart";
      fields.temperature = {
        name = "Cooling target";
        required = true;
        selector.number = {
          min = 68;
          max = 78;
          step = 0.5;
          unit_of_measurement = "F";
        };
      };
      sequence = [
        {
          action = "climate.set_hvac_mode";
          target.entity_id = thermostats;
          data.hvac_mode = "cool";
          continue_on_error = true;
        }
        {
          action = "climate.set_temperature";
          target.entity_id = thermostats;
          data.temperature = "{{ temperature | float }}";
          continue_on_error = true;
        }
        {
          wait_template = ''
            {{ states('climate.main_floor') == 'cool'
               and states('climate.master_suite') == 'cool'
               and (state_attr('climate.main_floor', 'temperature') | float(0)
                    - temperature | float) | abs <= 0.4
               and (state_attr('climate.master_suite', 'temperature') | float(0)
                    - temperature | float) | abs <= 0.4 }}
          '';
          timeout.seconds = 20;
          continue_on_timeout = true;
        }
        {
          "if" = [
            {
              condition = "template";
              value_template = "{{ not wait.completed }}";
            }
          ];
          "then" = [
            {
              action = "climate.set_hvac_mode";
              target.entity_id = thermostats;
              data.hvac_mode = "cool";
              continue_on_error = true;
            }
            {
              action = "climate.set_temperature";
              target.entity_id = thermostats;
              data.temperature = "{{ temperature | float }}";
              continue_on_error = true;
            }
            {
              wait_template = ''
                {{ states('climate.main_floor') == 'cool'
                   and states('climate.master_suite') == 'cool'
                   and (state_attr('climate.main_floor', 'temperature') | float(0)
                        - temperature | float) | abs <= 0.4
                   and (state_attr('climate.master_suite', 'temperature') | float(0)
                        - temperature | float) | abs <= 0.4 }}
              '';
              timeout.seconds = 20;
              continue_on_timeout = true;
            }
          ];
        }
        {
          "if" = [
            {
              condition = "template";
              value_template = "{{ not wait.completed }}";
            }
          ];
          "then" = [
            {
              action = "persistent_notification.create";
              data = {
                notification_id = climateFailureNotification;
                title = "Ecobee target change failed";
                message = "Both thermostats did not reach {{ temperature }} F after two attempts.";
              };
            }
          ];
          "else" = [
            {
              action = "persistent_notification.dismiss";
              data.notification_id = climateFailureNotification;
              continue_on_error = true;
            }
          ];
        }
      ];
    };

    script.apply_climate_policy = {
      alias = "Apply Climate Policy";
      description = "Resolve Vacation, manual override, Away, Sleep, and Home in that order and apply one Ecobee state.";
      icon = "mdi:home-thermometer";
      mode = "restart";
      sequence = [
        {
          variables = {
            policy_active = ''
              {{ states('input_boolean.goodnight') in ['on', 'off']
                 and states('input_boolean.vacation_mode') in ['on', 'off']
                 and (states('person.edmund_miller') not in ['unknown', 'unavailable']
                      or states('sensor.edmunds_iphone_ssid') not in ['unknown', 'unavailable'])
                 and (states('person.moni') not in ['unknown', 'unavailable']
                      or states('sensor.monicas_iphone_ssid') not in ['unknown', 'unavailable'])
                 and not is_state('binary_sensor.eve_door_20ebn9901_door', 'on') }}
            '';
            occupied = ''
              {{ is_state('person.edmund_miller', 'home')
                 or is_state('person.moni', 'home')
                 or is_state('sensor.edmunds_iphone_ssid', 'Aviato')
                 or is_state('sensor.monicas_iphone_ssid', 'Aviato') }}
            '';
            latest_presence_change = ''
              {{ [
                   as_timestamp(states.person.edmund_miller.last_changed, now().timestamp()),
                   as_timestamp(states.person.moni.last_changed, now().timestamp()),
                   as_timestamp(states.sensor.edmunds_iphone_ssid.last_changed, now().timestamp()),
                   as_timestamp(states.sensor.monicas_iphone_ssid.last_changed, now().timestamp())
                 ] | max }}
            '';
          };
        }
        {
          variables.away_long_enough = ''
            {{ not occupied
               and latest_presence_change | float > 0
               and latest_presence_change | float <= now().timestamp() - 7200 }}
          '';
        }
        {
          variables = {
            desired_profile = ''
              {% if away_long_enough %}
                away
              {% elif is_state('input_boolean.goodnight', 'on') %}
                sleep
              {% else %}
                home
              {% endif %}
            '';
            expected_profile_temperature = ''
              {% if away_long_enough %}
                76
              {% else %}
                72
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
                  value_template = "{{ not policy_active }}";
                }
              ];
              sequence = [
                {
                  action = "button.press";
                  target.entity_id = clearHoldButtons;
                }
              ];
            }
            {
              conditions = [
                {
                  condition = "state";
                  entity_id = "input_boolean.vacation_mode";
                  state = "on";
                }
              ];
              sequence = [
                {
                  action = "timer.cancel";
                  target.entity_id = "timer.climate_manual_override";
                }
                {
                  action = "script.apply_ecobee_target";
                  data.temperature = 78;
                }
              ];
            }
            {
              conditions = [
                {
                  condition = "state";
                  entity_id = "timer.climate_manual_override";
                  state = "active";
                }
              ];
              sequence = [
                {
                  action = "script.apply_ecobee_target";
                  data.temperature = "{{ states('input_number.climate_manual_override_target') | float(74) }}";
                }
              ];
            }
          ];
          default = [
            {
              action = "script.apply_ecobee_profile";
              data = {
                profile = "{{ desired_profile | trim }}";
                expected_temperature = "{{ expected_profile_temperature | float }}";
              };
            }
          ];
        }
      ];
    };

    script.activate_climate_manual_override = {
      alias = "Use Temporary Climate Target";
      description = "Apply one target to both thermostats for two hours, then restore the active comfort profile.";
      icon = "mdi:dog-side";
      mode = "restart";
      fields.temperature = {
        name = "Cooling target";
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
        description = "Apply Ecobee profiles only on startup, presence, sleep, and vacation transitions; ordinary Away waits two hours.";
        mode = "restart";
        trigger = [
          {
            platform = "homeassistant";
            event = "start";
          }
          {
            platform = "state";
            entity_id =
              people
              ++ homeWifiSsids
              ++ [
                "input_boolean.goodnight"
                "input_boolean.vacation_mode"
              ];
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
        ];
        action = [
          {
            action = "script.apply_climate_policy";
          }
        ];
      }
      {
        alias = "Respect HA manual climate target";
        id = "climate_manual_override_detected";
        description = "Apply an authenticated HA thermostat change to both Ecobees for two hours.";
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
            action = "script.apply_climate_policy";
          }
        ];
      }
      {
        alias = "Resume climate profile after manual override";
        id = "climate_manual_override_finished";
        description = "Restore the active Home, Sleep, or Away profile when the two-hour target expires.";
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
        description = "Release holds and stop both systems after the front door remains open for five minutes.";
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
        ];
      }
      {
        alias = "Resume climate when front door closes";
        id = "climate_resume_front_door_closed";
        description = "Restore the active exception or comfort profile when the front door closes.";
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
