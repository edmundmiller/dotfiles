# Alarm-relative wake/sleep scheduler for the sleep domain.
#
# Calculates bedtime phases from Edmund's next iPhone alarm when Edmund is home.
# Imported by ./default.nix so the main sleep domain file can keep scenes/scripts
# separate from the schedule/homeostasis logic.
{ lib, ... }:
let
  inherit (import ../../_lib.nix) ensureEnabled;

  edmund = {
    # iPhone next alarm datetime from the Home Assistant companion app. This is
    # the schedule source for the ADR: wake time -> sleep target -> bedtime phases.
    nextAlarm = "sensor.edmunds_iphone_next_alarm";

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
        {
          condition = "template";
          value_template = "{{ states('${edmund.nextAlarm}') not in ['unknown', 'unavailable', 'none', ''] }}";
        }
      ];
      variables = {
        # Keep these as timestamps to avoid HA/Jinja native datetime edge cases.
        alarm_ts = "{{ as_timestamp(states('${edmund.nextAlarm}')) }}";
        schedule_key = "{{ states('${edmund.nextAlarm}') }}";
        now_ts = "{{ now().timestamp() }}";
        sleep_ts = "{{ alarm_ts | float - 9 * 60 * 60 }}";
        winding_down_ts = "{{ sleep_ts | float - 60 * 60 }}";
        goodnight_ts = "{{ sleep_ts | float - 15 * 60 }}";
        get_ready_ts = "{{ goodnight_ts | float - 10 * 60 }}";
        get_ready_done_ts = "{{ states.input_boolean.get_ready_for_bed_done.last_changed.timestamp() }}";
        goodnight_done_ts = "{{ states.input_boolean.goodnight_done.last_changed.timestamp() }}";
        active_key = "{{ states('input_text.sleep_schedule_key') }}";
        is_new_schedule = "{{ active_key != schedule_key }}";
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
              # Never skip Get Ready for Bed. If we are late, this fires first
              # and later phases key off helper last_changed to preserve spacing.
              conditions = [
                {
                  condition = "template";
                  value_template = "{{ now_ts | float >= get_ready_ts | float and is_state('input_boolean.get_ready_for_bed_done', 'off') }}";
                }
              ];
              sequence = [
                {
                  action = "script.turn_on";
                  target.entity_id = "script.get_ready_for_bed";
                }
                {
                  action = "${edmund.notify}";
                  data = {
                    title = "🛏️ Get Ready for Bed";
                    message = "Start bedtime prep. Good Night target is {{ goodnight_ts | timestamp_custom('%-I:%M %p', true) }}.";
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
                    message = "Time to get in bed. Sleep target is {{ sleep_ts | timestamp_custom('%-I:%M %p', true) }} for {{ alarm_ts | timestamp_custom('%-I:%M %p', true) }} alarm.";
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
              # Skip Winding Down if we are already at/past Get Ready.
              conditions = [
                {
                  condition = "template";
                  value_template = "{{ now_ts | float >= winding_down_ts | float and now_ts | float < get_ready_ts | float and is_state('input_boolean.winding_down_done', 'off') }}";
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
