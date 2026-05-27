# Alarm-relative wake/sleep scheduler for the sleep domain.
#
# Calculates bedtime phases from Edmund's Eight Sleep smart alarm when Edmund is home.
# Imported by ./default.nix so the main sleep domain file can keep scenes/scripts
# separate from the schedule/homeostasis logic.
{ lib, ... }:
let
  inherit (import ../../_lib.nix) ensureEnabled;

  edmund = {
    # Eight Sleep next alarm timestamp. iOS Home Assistant Companion does not
    # expose a passive next-alarm sensor, so use the existing Eight Sleep alarm as
    # tonight's schedule source: latest wake time -> ideal smart-window wake
    # target -> sleep target -> bedtime phases.
    nextAlarm = "sensor.edmund_s_eight_sleep_side_next_alarm";

    # Person presence entity; the homeostasis automation only runs when Edmund
    # is home so travel/away alarms do not drive apartment lighting.
    presence = "person.edmund_miller";

    # Edmund's phone notification service. Monica is intentionally future-only
    # until the fallback alarm/presence path is added.
    notify = "notify.mobile_app_edmunds_iphone";
  };
in
{
  services.home-assistant.config.automation = lib.mkAfter (ensureEnabled [

    # Keep the Eight Sleep alarm fresh only during the evening decision window.
    # The integration can lag after changing the smart alarm in the app; forcing
    # an entity update every couple of minutes here keeps the scheduler aligned
    # without polling the cloud all day.
    {
      alias = "Refresh Eight Sleep Wake Schedule";
      id = "refresh_eight_sleep_wake_schedule";
      description = "Refresh Eight Sleep alarm during the bedtime planning window";
      mode = "single";
      trigger = {
        platform = "time_pattern";
        minutes = "/2";
      };
      condition = [
        {
          condition = "time";
          after = "19:30:00";
          before = "23:00:00";
        }
        {
          condition = "state";
          entity_id = edmund.presence;
          state = "home";
        }
      ];
      action = [
        {
          action = "homeassistant.update_entity";
          target.entity_id = edmund.nextAlarm;
        }
      ];
    }

    # Alarm-relative sleep lifecycle. Checks every 5 minutes 8 PM–midnight.
    {
      alias = "Circadian Sleep Homeostasis";
      id = "circadian_sleep_homeostasis";
      description = "Alarm-driven Winding Down → Get Ready for Bed → Good Night → Sleep lifecycle";
      mode = "single";
      trigger = {
        platform = "time_pattern";
        minutes = "/5";
      };
      condition = [
        {
          condition = "time";
          after = "20:00:00";
          before = "00:00:00";
        }
        {
          condition = "state";
          entity_id = edmund.presence;
          state = "home";
        }
      ];
      variables = {
        raw_alarm = "{{ states('${edmund.nextAlarm}') }}";
        # Default latest wake time if Eight Sleep has no readable next alarm:
        # 7:45 AM for Monday-Friday wake days, 8:00 AM for Saturday/Sunday wake
        # days. The ideal wake target is 30 minutes earlier, at the start of the
        # Eight Sleep smart-alarm window.
        #
        # HA renders automation variables independently, so derived timestamps
        # intentionally duplicate the wake-time expression instead of referring
        # to sibling variables such as `default_alarm_ts` or `alarm_ts`.
        alarm_ts = ''
          {%- set raw_alarm = states('${edmund.nextAlarm}') -%}
          {%- set wake = now() + timedelta(days=1) -%}
          {%- set weekend = wake.isoweekday() in [6, 7] -%}
          {%- set fallback = as_timestamp(wake.replace(hour=(8 if weekend else 7), minute=(0 if weekend else 45), second=0, microsecond=0)) -%}
          {%- if raw_alarm not in ['unknown', 'unavailable', 'none', ""] -%}
            {{ as_timestamp(raw_alarm, fallback) }}
          {%- else -%}
            {{ fallback }}
          {%- endif -%}
        '';
        schedule_key = ''
          {%- set raw_alarm = states('${edmund.nextAlarm}') -%}
          {%- set wake = now() + timedelta(days=1) -%}
          {%- set weekend = wake.isoweekday() in [6, 7] -%}
          {%- set fallback = as_timestamp(wake.replace(hour=(8 if weekend else 7), minute=(0 if weekend else 45), second=0, microsecond=0)) -%}
          {%- if raw_alarm not in ['unknown', 'unavailable', 'none', ""] -%}
            {{ raw_alarm }}
          {%- else -%}
            default:{{ fallback | timestamp_custom('%Y-%m-%dT%H:%M:%S%z', true) }}
          {%- endif -%}
        '';
        now_ts = "{{ now().timestamp() }}";
        ideal_wake_ts = ''
          {%- set raw_alarm = states('${edmund.nextAlarm}') -%}
          {%- set wake = now() + timedelta(days=1) -%}
          {%- set weekend = wake.isoweekday() in [6, 7] -%}
          {%- set fallback = as_timestamp(wake.replace(hour=(8 if weekend else 7), minute=(0 if weekend else 45), second=0, microsecond=0)) -%}
          {%- set latest_wake = as_timestamp(raw_alarm, fallback) if raw_alarm not in ['unknown', 'unavailable', 'none', ""] else fallback -%}
          {{ latest_wake - 30 * 60 }}
        '';
        sleep_ts = ''
          {%- set raw_alarm = states('${edmund.nextAlarm}') -%}
          {%- set wake = now() + timedelta(days=1) -%}
          {%- set weekend = wake.isoweekday() in [6, 7] -%}
          {%- set fallback = as_timestamp(wake.replace(hour=(8 if weekend else 7), minute=(0 if weekend else 45), second=0, microsecond=0)) -%}
          {%- set latest_wake = as_timestamp(raw_alarm, fallback) if raw_alarm not in ['unknown', 'unavailable', 'none', ""] else fallback -%}
          {%- set ideal_wake = latest_wake - 30 * 60 -%}
          {{ ideal_wake - 6 * 90 * 60 }}
        '';
        winding_down_ts = ''
          {%- set raw_alarm = states('${edmund.nextAlarm}') -%}
          {%- set wake = now() + timedelta(days=1) -%}
          {%- set weekend = wake.isoweekday() in [6, 7] -%}
          {%- set fallback = as_timestamp(wake.replace(hour=(8 if weekend else 7), minute=(0 if weekend else 45), second=0, microsecond=0)) -%}
          {%- set latest_wake = as_timestamp(raw_alarm, fallback) if raw_alarm not in ['unknown', 'unavailable', 'none', ""] else fallback -%}
          {%- set ideal_wake = latest_wake - 30 * 60 -%}
          {{ ideal_wake - 6 * 90 * 60 - 60 * 60 }}
        '';
        goodnight_ts = ''
          {%- set raw_alarm = states('${edmund.nextAlarm}') -%}
          {%- set wake = now() + timedelta(days=1) -%}
          {%- set weekend = wake.isoweekday() in [6, 7] -%}
          {%- set fallback = as_timestamp(wake.replace(hour=(8 if weekend else 7), minute=(0 if weekend else 45), second=0, microsecond=0)) -%}
          {%- set latest_wake = as_timestamp(raw_alarm, fallback) if raw_alarm not in ['unknown', 'unavailable', 'none', ""] else fallback -%}
          {%- set ideal_wake = latest_wake - 30 * 60 -%}
          {{ ideal_wake - 6 * 90 * 60 - 15 * 60 }}
        '';
        get_ready_ts = ''
          {%- set raw_alarm = states('${edmund.nextAlarm}') -%}
          {%- set wake = now() + timedelta(days=1) -%}
          {%- set weekend = wake.isoweekday() in [6, 7] -%}
          {%- set fallback = as_timestamp(wake.replace(hour=(8 if weekend else 7), minute=(0 if weekend else 45), second=0, microsecond=0)) -%}
          {%- set latest_wake = as_timestamp(raw_alarm, fallback) if raw_alarm not in ['unknown', 'unavailable', 'none', ""] else fallback -%}
          {%- set ideal_wake = latest_wake - 30 * 60 -%}
          {{ ideal_wake - 6 * 90 * 60 - 25 * 60 }}
        '';
        get_ready_done_ts = "{{ states.input_boolean.get_ready_for_bed_done.last_changed.timestamp() }}";
        goodnight_done_ts = "{{ states.input_boolean.goodnight_done.last_changed.timestamp() }}";
        active_key = "{{ states('input_text.sleep_schedule_key') }}";
        # Do not reference sibling `schedule_key` here: HA renders automation
        # variables independently. If this accidentally evaluates truthy on
        # every 5-minute tick, the helper booleans reset and notifications repeat.
        is_new_schedule = ''
          {%- set raw_alarm = states('${edmund.nextAlarm}') -%}
          {%- set wake = now() + timedelta(days=1) -%}
          {%- set weekend = wake.isoweekday() in [6, 7] -%}
          {%- set fallback = as_timestamp(wake.replace(hour=(8 if weekend else 7), minute=(0 if weekend else 45), second=0, microsecond=0)) -%}
          {%- if raw_alarm not in ['unknown', 'unavailable', 'none', ""] -%}
            {{ states('input_text.sleep_schedule_key') != raw_alarm }}
          {%- else -%}
            {{ states('input_text.sleep_schedule_key') != ('default:' ~ (fallback | timestamp_custom('%Y-%m-%dT%H:%M:%S%z', true))) }}
          {%- endif -%}
        '';
      };
      action = [
        {
          "if" = [
            {
              condition = "template";
              value_template = "{{ is_new_schedule }}";
            }
          ];
          "then" = [
            {
              action = "input_text.set_value";
              target.entity_id = "input_text.sleep_schedule_key";
              data.value = "{{ schedule_key }}";
            }
            {
              action = "input_boolean.turn_off";
              target.entity_id = [
                "input_boolean.winding_down_done"
                "input_boolean.get_ready_for_bed_done"
                "input_boolean.goodnight_done"
                "input_boolean.sleep_done"
              ];
            }
          ];
        }
        {
          choose = [
            {
              # Never skip Get Ready for Bed while the house is not already in
              # Good Night. If someone is already in bed, do not re-run prep
              # scenes that can bring living-space lights back up.
              conditions = [
                {
                  condition = "template";
                  value_template = "{{ is_state('input_boolean.goodnight', 'off') and now_ts | float >= get_ready_ts | float and is_state('input_boolean.get_ready_for_bed_done', 'off') }}";
                }
              ];
              sequence = [
                {
                  action = "script.turn_on";
                  target.entity_id = "script.get_ready_for_bed";
                }
                # Set the phase helper explicitly before notifying so the
                # 5-minute homeostasis loop cannot send repeated nudges if the
                # script is still running or fails before updating the helper.
                {
                  action = "input_boolean.turn_on";
                  target.entity_id = "input_boolean.get_ready_for_bed_done";
                }
                {
                  action = "${edmund.notify}";
                  data = {
                    title = "🛏️ Get Ready for Bed";
                    message = "Start bedtime prep. Good Night target is {{ goodnight_ts | timestamp_custom('%-I:%M %p', true) }}.";
                    data = {
                      tag = "sleep_get_ready_for_bed";
                      push = {
                        "interruption-level" = "time-sensitive";
                        sound = "default";
                      };
                    };
                  };
                }
              ];
            }
            {
              conditions = [
                {
                  condition = "template";
                  value_template = "{{ is_state('input_boolean.get_ready_for_bed_done', 'on') and now_ts | float >= goodnight_ts | float and now_ts | float >= get_ready_done_ts | float + 600 and is_state('input_boolean.goodnight_done', 'off') }}";
                }
              ];
              sequence = [
                {
                  action = "script.turn_on";
                  target.entity_id = "script.goodnight";
                }
                {
                  action = "${edmund.notify}";
                  data = {
                    title = "🛏️ Good Night";
                    message = "Time to get in bed. Sleep target is {{ sleep_ts | timestamp_custom('%-I:%M %p', true) }} for {{ ideal_wake_ts | timestamp_custom('%-I:%M %p', true) }}–{{ alarm_ts | timestamp_custom('%-I:%M %p', true) }} smart wake window.";
                  };
                }
                # Future: also notify Monica when her alarm/presence path is added.
                # { action = "notify.mobile_app_monicas_iphone"; data = { title = "🛏️ Good Night"; message = "Time to get in bed."; }; }
              ];
            }
            {
              conditions = [
                {
                  condition = "template";
                  value_template = "{{ is_state('input_boolean.goodnight_done', 'on') and now_ts | float >= sleep_ts | float and now_ts | float >= goodnight_done_ts | float + 900 and is_state('input_boolean.sleep_done', 'off') }}";
                }
              ];
              sequence = [
                {
                  action = "script.turn_on";
                  target.entity_id = "script.sleep";
                }
              ];
            }
            {
              # Skip Winding Down if we are already at/past Get Ready, or if
              # Good Night is already active from a manual/in-bed path.
              conditions = [
                {
                  condition = "template";
                  value_template = "{{ is_state('input_boolean.goodnight', 'off') and now_ts | float >= winding_down_ts | float and now_ts | float < get_ready_ts | float and is_state('input_boolean.winding_down_done', 'off') }}";
                }
              ];
              sequence = [
                {
                  action = "scene.turn_on";
                  target.entity_id = "scene.winding_down";
                }
                {
                  action = "input_boolean.turn_on";
                  target.entity_id = "input_boolean.winding_down_done";
                }
              ];
            }
          ];
        }
      ];
    }

  ]);
}
