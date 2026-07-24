# Adaptive mapped-room cleaning for Rosie (Roomba i7) and Squirty (Braava m6).
{ lib, ... }:
let
  inherit (import ../_lib.nix) ensureEnabled;

  notifyException = message: {
    action = "notify.mobile_app_edmunds_iphone";
    data = {
      title = "Robot cleaning needs attention";
      inherit message;
    };
  };

  dockBoth = {
    action = "vacuum.return_to_base";
    continue_on_error = true;
    target.entity_id = [
      "vacuum.rosie"
      "vacuum.squirty"
    ];
  };

  freshStableAbsenceTemplate = ''
    {% set now_ts = as_timestamp(now()) %}
    {% set edmund = states.device_tracker.edmunds_iphone %}
    {% set monica = states.device_tracker.monicas_iphone %}
    {{ states('device_tracker.edmunds_iphone') not in ['home', 'Parking Lot', 'unknown', 'unavailable']
       and states('device_tracker.monicas_iphone') not in ['home', 'Parking Lot', 'unknown', 'unavailable']
       and now_ts - as_timestamp(edmund.last_changed, 0) >= 600
       and now_ts - as_timestamp(monica.last_changed, 0) >= 600
       and now_ts - as_timestamp(edmund.last_updated, 0) <= 7200
       and now_ts - as_timestamp(monica.last_updated, 0) <= 7200 }}
  '';

  selectDueJobTemplate = excludedExpression: ''
    {% set now_ts = as_timestamp(now()) %}
    {% set excluded = ${excludedExpression} %}
    {% set ns = namespace(jobs=[]) %}
    {% set rosie_high_interval = 48 * 60 * 60 %}
    {% set rosie_remaining_interval = 7 * 24 * 60 * 60 %}
    {% set squirty_high_interval = 3 * 24 * 60 * 60 %}
    {% set rosie_high_overdue = now_ts - as_timestamp(states('input_datetime.robot_cleaning_rosie_high_traffic_last_success'), 0) - rosie_high_interval %}
    {% set rosie_remaining_overdue = now_ts - as_timestamp(states('input_datetime.robot_cleaning_rosie_remaining_last_success'), 0) - rosie_remaining_interval %}
    {% set squirty_high_overdue = now_ts - as_timestamp(states('input_datetime.robot_cleaning_squirty_high_traffic_last_success'), 0) - squirty_high_interval %}
    {% if rosie_high_overdue >= 0 and excluded != 'rosie_high_traffic' %}
      {% set ns.jobs = ns.jobs + [dict(id='rosie_high_traffic', overdue=rosie_high_overdue)] %}
    {% endif %}
    {% if rosie_remaining_overdue >= 0 and excluded != 'rosie_remaining' %}
      {% set ns.jobs = ns.jobs + [dict(id='rosie_remaining', overdue=rosie_remaining_overdue)] %}
    {% endif %}
    {% if squirty_high_overdue >= 0 and excluded != 'squirty_high_traffic' %}
      {% set ns.jobs = ns.jobs + [dict(id='squirty_high_traffic', overdue=squirty_high_overdue)] %}
    {% endif %}
    {% set ranked = ns.jobs | sort(attribute='overdue', reverse=true) %}
    {{ ranked[0].id if ranked else "" }}
  '';
in
{
  services.home-assistant.config = {
    input_boolean = {
      robot_cleaning_enabled = {
        name = "Robot Cleaning Enabled";
        icon = "mdi:robot-vacuum";
      };
      robot_cleaning_two_job_enabled = {
        name = "Robot Cleaning Two-job Chaining";
        icon = "mdi:robot-vacuum-variant";
      };
    };

    input_datetime = {
      robot_cleaning_last_dispatch = {
        name = "Robot Cleaning Last Dispatch";
        has_date = true;
        has_time = true;
      };
      robot_cleaning_rosie_high_traffic_last_success = {
        name = "Rosie High-traffic Last Success";
        has_date = true;
        has_time = true;
      };
      robot_cleaning_rosie_remaining_last_success = {
        name = "Rosie Remaining Rooms Last Success";
        has_date = true;
        has_time = true;
      };
      robot_cleaning_squirty_high_traffic_last_success = {
        name = "Squirty High-traffic Last Success";
        has_date = true;
        has_time = true;
      };
    };

    input_text = {
      robot_cleaning_rosie_pmap_id = {
        name = "Rosie Map ID";
        max = 100;
      };
      robot_cleaning_rosie_user_pmapv_id = {
        name = "Rosie Map Version";
        max = 100;
      };
      robot_cleaning_rosie_high_traffic_region_ids = {
        name = "Rosie High-traffic Region IDs";
        max = 255;
      };
      robot_cleaning_rosie_remaining_region_ids = {
        name = "Rosie Remaining Region IDs";
        max = 255;
      };
      robot_cleaning_squirty_pmap_id = {
        name = "Squirty Map ID";
        max = 100;
      };
      robot_cleaning_squirty_user_pmapv_id = {
        name = "Squirty Map Version";
        max = 100;
      };
      robot_cleaning_squirty_high_traffic_region_ids = {
        name = "Squirty High-traffic Region IDs";
        max = 255;
      };
    };

    counter.robot_cleaning_pilot_successes = {
      name = "Robot Cleaning Pilot Successes";
      icon = "mdi:counter";
      minimum = 0;
      maximum = 3;
      step = 1;
      restore = true;
    };

    script = {
      robot_cleaning_run_job = {
        alias = "Run one mapped robot cleaning job";
        description = "Fail-closed mapped-room mission with readiness, arrival, mission-counter, and watchdog guards";
        mode = "single";
        sequence = [
          {
            variables = {
              robot = "{{ 'vacuum.squirty' if job == 'squirty_high_traffic' else 'vacuum.rosie' }}";
              battery_sensor = "{{ 'sensor.squirty_battery' if job == 'squirty_high_traffic' else 'sensor.rosie_battery' }}";
              success_sensor = "{{ 'sensor.squirty_successful_missions' if job == 'squirty_high_traffic' else 'sensor.rosie_successful_missions' }}";
              failed_sensor = "{{ 'sensor.squirty_failed_missions' if job == 'squirty_high_traffic' else 'sensor.rosie_failed_missions' }}";
              canceled_sensor = "{{ 'sensor.squirty_canceled_missions' if job == 'squirty_high_traffic' else 'sensor.rosie_canceled_missions' }}";
              pilot_run = "{{ count_pilot | default(false) | bool(false) }}";
              last_success_entity = "{{ 'input_datetime.robot_cleaning_rosie_high_traffic_last_success' if job == 'rosie_high_traffic' else ('input_datetime.robot_cleaning_rosie_remaining_last_success' if job == 'rosie_remaining' else 'input_datetime.robot_cleaning_squirty_high_traffic_last_success') }}";
              pmap_entity = "{{ 'input_text.robot_cleaning_squirty_pmap_id' if job == 'squirty_high_traffic' else 'input_text.robot_cleaning_rosie_pmap_id' }}";
              map_version_entity = "{{ 'input_text.robot_cleaning_squirty_user_pmapv_id' if job == 'squirty_high_traffic' else 'input_text.robot_cleaning_rosie_user_pmapv_id' }}";
              region_ids_entity = "{{ 'input_text.robot_cleaning_rosie_high_traffic_region_ids' if job == 'rosie_high_traffic' else ('input_text.robot_cleaning_rosie_remaining_region_ids' if job == 'rosie_remaining' else 'input_text.robot_cleaning_squirty_high_traffic_region_ids') }}";
              ready = ''
                {% set map_ready = states(pmap_entity) not in ["", "unknown", "unavailable"]
                   and states(map_version_entity) not in ["", "unknown", "unavailable"]
                   and states(region_ids_entity) not in ["", "unknown", "unavailable"] %}
                {% set base_ready = is_state(robot, 'docked')
                   and states(battery_sensor) | int(0) >= 50 %}
                {% if job == 'squirty_high_traffic' %}
                  {{ map_ready and base_ready
                     and state_attr('vacuum.squirty', 'tank_present') == true
                     and state_attr('vacuum.squirty', 'tank_level') | int(0) > 0
                     and state_attr('vacuum.squirty', 'detected_pad') not in [none, "", "unknown"] }}
                {% else %}
                  {{ map_ready and base_ready
                     and state_attr('vacuum.rosie', 'bin_present') == true
                     and is_state('binary_sensor.rosie_bin_full', 'off') }}
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
                    value_template = "{{ not (ready | bool(false)) }}";
                  }
                ];
                sequence = [
                  (notifyException "Scheduled job {{ job }} was blocked. Check map IDs, battery, dock state, and the robot's bin/tank/pad.")
                  {
                    stop = "Robot job readiness failed";
                    error = false;
                  }
                ];
              }
            ];
          }
          {
            variables = {
              success_before = "{{ states(success_sensor) | int(0) }}";
              failed_before = "{{ states(failed_sensor) | int(0) }}";
              canceled_before = "{{ states(canceled_sensor) | int(0) }}";
              pilot_before = "{{ states('counter.robot_cleaning_pilot_successes') | int(0) }}";
            };
          }
          {
            action = "vacuum.send_command";
            target.entity_id = "{{ robot }}";
            data = {
              command = "start";
              params = ''
                {% set ns = namespace(regions=[]) %}
                {% for region_id in states(region_ids_entity).split(',') | map('trim') | reject('equalto', "") | list %}
                  {% set ns.regions = ns.regions + [dict(region_id=region_id, type='rid')] %}
                {% endfor %}
                {{ dict(
                  pmap_id=states(pmap_entity),
                  user_pmapv_id=states(map_version_entity),
                  regions=ns.regions
                ) }}
              '';
            };
          }
          {
            wait_template = ''
              {{ is_state(robot, 'cleaning')
                 or states(success_sensor) | int(0) > success_before | int(0)
                 or states(failed_sensor) | int(0) > failed_before | int(0)
                 or states(canceled_sensor) | int(0) > canceled_before | int(0)
                 or states('device_tracker.edmunds_iphone') in ['home', 'Parking Lot']
                 or states('device_tracker.monicas_iphone') in ['home', 'Parking Lot'] }}
            '';
            timeout = "00:02:00";
            continue_on_timeout = true;
          }
          {
            choose = [
              {
                conditions = [
                  {
                    condition = "template";
                    value_template = ''
                      {{ states('device_tracker.edmunds_iphone') in ['home', 'Parking Lot']
                         or states('device_tracker.monicas_iphone') in ['home', 'Parking Lot'] }}
                    '';
                  }
                ];
                sequence = [
                  dockBoth
                  {
                    stop = "Arrival interrupted robot startup";
                    error = false;
                  }
                ];
              }
              {
                conditions = [
                  {
                    condition = "template";
                    value_template = "{{ not is_state(robot, 'cleaning') and states(success_sensor) | int(0) <= success_before | int(0) }}";
                  }
                ];
                sequence = [
                  (notifyException "Scheduled job {{ job }} did not start. Revalidate its saved-map version and region IDs.")
                  dockBoth
                  {
                    stop = "Robot did not start mapped-room mission";
                    error = false;
                  }
                ];
              }
            ];
          }
          {
            wait_template = ''
              {{ states(success_sensor) | int(0) > success_before | int(0)
                 or states(failed_sensor) | int(0) > failed_before | int(0)
                 or states(canceled_sensor) | int(0) > canceled_before | int(0)
                 or is_state(robot, 'error')
                 or states('device_tracker.edmunds_iphone') in ['home', 'Parking Lot']
                 or states('device_tracker.monicas_iphone') in ['home', 'Parking Lot'] }}
            '';
            timeout = "01:30:00";
            continue_on_timeout = true;
          }
          {
            choose = [
              {
                conditions = [
                  {
                    condition = "template";
                    value_template = "{{ states(success_sensor) | int(0) > success_before | int(0) }}";
                  }
                ];
                sequence = [
                  {
                    action = "input_datetime.set_datetime";
                    target.entity_id = "{{ last_success_entity | trim }}";
                    data.datetime = "{{ now().strftime('%Y-%m-%d %H:%M:%S') }}";
                  }
                  {
                    "if" = [
                      {
                        condition = "template";
                        value_template = "{{ pilot_run | bool(false) and pilot_before | int(0) < 3 }}";
                      }
                    ];
                    "then" = [
                      {
                        action = "counter.increment";
                        target.entity_id = "counter.robot_cleaning_pilot_successes";
                      }
                    ];
                  }
                  {
                    "if" = [
                      {
                        condition = "template";
                        value_template = "{{ pilot_run | bool(false) and pilot_before | int(0) == 2 }}";
                      }
                    ];
                    "then" = [
                      (notifyException "Three pilot jobs completed. Review Phoebe's response before enabling two-job chaining.")
                    ];
                  }
                ];
              }
            ];
            default = [
              dockBoth
              {
                "if" = [
                  {
                    condition = "template";
                    value_template = ''
                      {{ states('device_tracker.edmunds_iphone') not in ['home', 'Parking Lot']
                         and states('device_tracker.monicas_iphone') not in ['home', 'Parking Lot'] }}
                    '';
                  }
                ];
                "then" = [
                  (notifyException "Scheduled job {{ job }} failed, was canceled, or reached its 90-minute watchdog. It remains due for a future day.")
                ];
              }
            ];
          }
        ];
      };

      robot_cleaning_dispatch = {
        alias = "Dispatch overdue robot cleaning";
        description = "Select the most overdue mapped-room job and optionally run one approved follow-up";
        mode = "single";
        sequence = [
          {
            variables = {
              rosie_high_interval = "{{ 48 * 60 * 60 }}";
              rosie_remaining_interval = "{{ 7 * 24 * 60 * 60 }}";
              squirty_high_interval = "{{ 3 * 24 * 60 * 60 }}";
              selected_job = selectDueJobTemplate "''";
              selected_last_success_entity = "{{ 'input_datetime.robot_cleaning_rosie_high_traffic_last_success' if selected_job | trim == 'rosie_high_traffic' else ('input_datetime.robot_cleaning_rosie_remaining_last_success' if selected_job | trim == 'rosie_remaining' else 'input_datetime.robot_cleaning_squirty_high_traffic_last_success') }}";
            };
          }
          {
            condition = "template";
            value_template = "{{ selected_job | trim != '' }}";
          }
          {
            action = "input_datetime.set_datetime";
            target.entity_id = "input_datetime.robot_cleaning_last_dispatch";
            data.datetime = "{{ now().strftime('%Y-%m-%d %H:%M:%S') }}";
          }
          {
            action = "script.robot_cleaning_run_job";
            data = {
              job = "{{ selected_job | trim }}";
              count_pilot = true;
            };
          }
          {
            "if" = [
              {
                condition = "state";
                entity_id = "input_boolean.robot_cleaning_two_job_enabled";
                state = "on";
              }
              {
                condition = "numeric_state";
                entity_id = "counter.robot_cleaning_pilot_successes";
                above = 2;
              }
              {
                condition = "template";
                value_template = "{{ states(selected_last_success_entity)[:10] == now().date().isoformat() }}";
              }
              {
                condition = "time";
                after = "09:00:00";
                before = "20:00:00";
              }
              {
                condition = "template";
                value_template = freshStableAbsenceTemplate;
              }
              {
                condition = "state";
                entity_id = "input_boolean.robot_cleaning_enabled";
                state = "on";
              }
              {
                condition = "state";
                entity_id = "input_boolean.vacation_mode";
                state = "off";
              }
              {
                condition = "state";
                entity_id = "input_boolean.guest_mode";
                state = "off";
              }
              {
                condition = "state";
                entity_id = "input_boolean.goodnight";
                state = "off";
              }
            ];
            "then" = [
              {
                variables.second_job = selectDueJobTemplate "selected_job";
              }
              {
                condition = "template";
                value_template = "{{ second_job | trim != '' }}";
              }
              {
                action = "script.robot_cleaning_run_job";
                data = {
                  job = "{{ second_job | trim }}";
                  count_pilot = false;
                };
              }
            ];
          }
        ];
      };
    };

    automation = lib.mkAfter (ensureEnabled [
      {
        alias = "Robot cleaning scheduler";
        id = "robot_cleaning_scheduler";
        description = "Dispatch the most overdue room job during one stable, fresh, daytime empty-house window";
        trigger = {
          platform = "time_pattern";
          minutes = "/5";
        };
        condition = [
          {
            condition = "time";
            after = "09:00:00";
            before = "20:00:00";
          }
          {
            condition = "state";
            entity_id = "input_boolean.robot_cleaning_enabled";
            state = "on";
          }
          {
            condition = "state";
            entity_id = "input_boolean.vacation_mode";
            state = "off";
          }
          {
            condition = "state";
            entity_id = "input_boolean.guest_mode";
            state = "off";
          }
          {
            condition = "state";
            entity_id = "input_boolean.goodnight";
            state = "off";
          }
          {
            condition = "template";
            value_template = freshStableAbsenceTemplate;
          }
          {
            condition = "template";
            value_template = ''
              {{ states('input_datetime.robot_cleaning_last_dispatch')[:10]
                 != now().date().isoformat() }}
            '';
          }
        ];
        action = [
          {
            action = "script.robot_cleaning_dispatch";
          }
        ];
        mode = "single";
      }
      {
        alias = "Robot cleaning arrival dock";
        id = "robot_cleaning_arrival_dock";
        description = "Dock both robots as either phone reaches the parking lot or home";
        trigger = [
          {
            platform = "state";
            entity_id = "device_tracker.edmunds_iphone";
            to = "home";
          }
          {
            platform = "state";
            entity_id = "device_tracker.edmunds_iphone";
            to = "Parking Lot";
          }
          {
            platform = "state";
            entity_id = "device_tracker.monicas_iphone";
            to = "home";
          }
          {
            platform = "state";
            entity_id = "device_tracker.monicas_iphone";
            to = "Parking Lot";
          }
        ];
        condition = {
          condition = "template";
          value_template = "{{ not (is_state('vacuum.rosie', 'docked') and is_state('vacuum.squirty', 'docked')) }}";
        };
        action = [
          dockBoth
        ];
        mode = "restart";
      }
      {
        alias = "Robot cleaning exception monitor";
        id = "robot_cleaning_exception_monitor";
        description = "One daily exception check for stale phone presence or severely overdue jobs";
        trigger = {
          platform = "time";
          at = "12:00:00";
        };
        condition = {
          condition = "state";
          entity_id = "input_boolean.robot_cleaning_enabled";
          state = "on";
        };
        action = [
          {
            choose = [
              {
                conditions = [
                  {
                    condition = "template";
                    value_template = ''
                      {% set now_ts = as_timestamp(now()) %}
                      {{ states('device_tracker.edmunds_iphone') in ['unknown', 'unavailable']
                         or states('device_tracker.monicas_iphone') in ['unknown', 'unavailable']
                         or now_ts - as_timestamp(states.device_tracker.edmunds_iphone.last_updated, 0) > 7200
                         or now_ts - as_timestamp(states.device_tracker.monicas_iphone.last_updated, 0) > 7200 }}
                    '';
                  }
                ];
                sequence = [
                  (notifyException "Automatic cleaning is paused because one or both iPhone presence trackers are stale.")
                ];
              }
              {
                conditions = [
                  {
                    condition = "template";
                    value_template = ''
                      {% set now_ts = as_timestamp(now()) %}
                      {{ now_ts - as_timestamp(states('input_datetime.robot_cleaning_rosie_high_traffic_last_success'), 0) > 2 * 48 * 60 * 60
                         or now_ts - as_timestamp(states('input_datetime.robot_cleaning_rosie_remaining_last_success'), 0) > 2 * 7 * 24 * 60 * 60
                         or now_ts - as_timestamp(states('input_datetime.robot_cleaning_squirty_high_traffic_last_success'), 0) > 2 * 3 * 24 * 60 * 60 }}
                    '';
                  }
                ];
                sequence = [
                  (notifyException "At least one mapped-room job is overdue by twice its normal interval.")
                ];
              }
            ];
          }
        ];
      }
    ]);
  };
}
